require 'rubygems'
require 'sinatra'
require 'sha1'
require 'eventmachine'
require 'json'

set :public, Proc.new { File.join(root, 'public') }
set :views, Proc.new { File.join(root, 'views') }

puts "*** Must be run in production mode (-e production)"

module JsChat
  class Server
    attr_reader :connection

    def initialize(cookie)
      @cookie = cookie
      run
    end

    module EventServer
      include Rack::Utils
      alias_method :h, :escape_html

      def post_init
        @identified = false
        @messages = {}
        @disconnected = false
        @identification_error = nil

        watch_timeout
      end

      def polled
        @last_poll = Time.now
      end

      def watch_timeout
        @last_poll = Time.now

        Thread.new do
          loop do
            if Time.now - @last_poll > 120
              puts "TIMEOUT"
              close_connection
              return
            end
            sleep 120
          end
        end
      end

      def identification_error
        @identification_error
      end

      def identified?
        @identified
      end

      def messages(room)
        @messages ||= {}
        @messages[room] ||= []
        @messages[room]
      end

      def clear_messages(room)
        @messages ||= {}
        @messages[room] ||= []
        @messages[room].clear
      end

      def save_messages(messages)
        @messages ||= {}
        room = find_room(messages)
        @messages[room] ||= []
        @messages[room] << sanitize_json(messages).to_json
      end

      # This searches messages for a room name reference
      # It's currently assumed that server responses are per-room,
      # rather than a set of messages for multiple rooms
      def find_room(messages)
        if messages.kind_of? Array
          messages.each do |message|
            room_name = extract_room_name(message)
            return room_name if room_name
          end
        else
          return extract_room_name(messages)
        end
      end

      def extract_room_name(message)
        return unless message.kind_of? Hash

        message.each do |field, value|
          if field == 'room'
            return value
          elsif field == 'to'
            return value
          elsif value.kind_of? Hash
            return extract_room_name value
          elsif value.kind_of? Array
            return find_room(value)
          end
        end
      end

      def last_room=(room)
        @last_room = room
      end

      def last_room ; @last_room ; end
      def disconnected? ; @disconnected ; end

      def unbind
        puts "*** Server disconnecting.  Count now: #{JsChat::Bridge.servers.size}"
        JsChat::Bridge.servers.delete_if { |hash, server| server.connection == self }
        @disconnected = true
        puts "*** Server disconnected.  Count now: #{JsChat::Bridge.servers.size}"
      end

      def receive_data(data)
        data.split("\n").each do |line|
          json = {}
          begin
            json = JSON.parse(line)
          rescue JSON::ParserError
            puts "Error parsing:"
            p line
            return
          end

          puts "LINE FROM SERVER: #{line}"

          if @identified == false and json['identified']
            @identified = true
            @name = json['name']
          elsif @identified == false and json['display'] == 'error'
            @identification_error = json['error']
          elsif @identified
            save_messages json
          end
        end
      end

      def names(room)
        send_data({'names' => room}.to_json + "\n")
      end

      def lastlog(room)
        send_data({'lastlog' => room}.to_json + "\n")
      end

      def join(room)
        send_data({'join' => room}.to_json + "\n")
      end

      def sanitize_json(json)
        # Sanitize output
        json.each do |field, value|
          if value.kind_of? String
            json[field] = h value
          elsif value.kind_of? Hash
            json[field] = sanitize_json(value)
          elsif value.kind_of? Array
            json[field] = value.collect do |v|
              if v.kind_of? String
                h v
              else
                sanitize_json(v)
              end
            end
          end
        end
        json
      end
    end

    def quit
      @connection.close_connection
    end

    def identify(name)
      @connection.send_data({'identify' => name}.to_json + "\n")
    end

    def identified?
      @connection.identified?
    end

    def run
      EM.run do
        @connection = EM.connect '0.0.0.0', 6789, EventServer
      end
    end

    def recent_messages(room)
      messages = @connection.messages(room).dup
      @connection.clear_messages(room)
      messages
    end
    
    def send_message(message, room)
      @connection.send_data({ 'to' => room, 'send' => message }.to_json + "\n")
    end
  end

  class Bridge
    @@servers = {}
    attr_accessor :name, :server

    def initialize(cookie)
      @cookie = cookie
      setup_connection
    end

    def self.servers
      @@servers
    end

    def self.new_cookie
      SHA1.hexdigest Time.now.usec.to_s
    end

    def self.new_server(cookie)
      server = Server.new cookie
      @@servers[cookie] = server
    end

    def recent_messages(room)
      @server.recent_messages(room)
    end

    def setup_connection
      if @@servers[@cookie]
        @server = @@servers[@cookie]
      else
        Bridge.new_server(@cookie)
        @server = @@servers[@cookie]
      end
    end
  end
end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html

  def message_form
    html = <<-HTML
      <ul id="messages">
      </ul>
      <div id="info">
        <h2 id="room-name">Loading...</h2>
        <ul id="names"> 
        </ul>
      </div>
      <div id="input">
        <form method="post" action="/message" id="post_message">
          <input name="message" id="message" value="" type="text" autocomplete="off" />
          <input name="submit" type="submit" id="send_button" value="Send" />
        </form>
      </div>
    HTML
  end

  def load_bridge
    cookie = request.cookies['jschat-id']

    if cookie.nil?
      cookie = JsChat::Bridge.new_cookie
      response.set_cookie 'jschat-id', cookie
      JsChat::Bridge.new_server cookie
    end

    @bridge = JsChat::Bridge.new(cookie) 
  end

  def messages_js(room)
    '[' + @bridge.recent_messages(room).join(", ") + ']';
  end
end

# Identify
get '/' do
  load_bridge
  if @bridge and @bridge.server
    cookie = request.cookies['jschat-id']
    response.set_cookie 'jschat-id', nil
    @bridge.server.quit
  end
 
  erb :index
end

post '/identify' do
  load_bridge
  @bridge.server.identify params['name']
  @bridge.server.connection.last_room = params['room']
  redirect '/identify-pending'
end

# Invalid nick names should be handled using Ajax
get '/identify-pending' do
  load_bridge

  if @bridge.server.identified?
    redirect "/chat/#{@bridge.server.connection.last_room}"
  elsif @bridge.server.connection.identification_error
    @bridge.server.connection.identification_error.to_json
  else
    { 'action' => 'reload' }.to_json
  end
end

get '/messages' do
  load_bridge
  @bridge.server.connection.polled
  @bridge.server.connection.last_room = params['room']
  messages_js params['room']
end

get '/names' do
  load_bridge
  @bridge.server.connection.names params['room']
  @bridge.server.connection.last_room = params['room']
  "Request OK"
end

get '/lastlog' do
  load_bridge
  @bridge.server.connection.lastlog params['room']
  @bridge.server.connection.last_room = params['room']
  "Request OK"
end

post '/join' do
  load_bridge
  @bridge.server.connection.join(params['room'])
  @bridge.server.connection.last_room = params['room']
  "Request OK"
end

get '/chat/' do
  load_bridge

  if @bridge.server.identified?
    erb message_form
  else
    redirect '/'
  end
end

post '/message' do
  load_bridge
  @bridge.server.connection.last_room = params['to']
  @bridge.server.send_message params['message'], params['to']
  "Message posted"
end

post '/quit' do
  load_bridge
  @bridge.server.quit
  "Quit"
end
