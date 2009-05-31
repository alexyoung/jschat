require 'rubygems'
require 'sinatra'
require 'sha1'
require 'eventmachine'
require 'json'
require 'sprockets'

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
        room = last_room if room.nil?
        if room
          @messages[room] ||= []
          @messages[room] << sanitize_json(messages).to_json
        end
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
        elsif messages.kind_of? Hash
          return extract_room_name(messages)
        end
        return false
      end

      def extract_room_name(message)
        room_name = nil
        message.each do |field, value|
          if field == 'room'
            room_name = value
            true
          elsif field == 'to'
            room_name = value
            true
          elsif value.kind_of? Hash
            room_name = extract_room_name(value)
          elsif value.kind_of? Array
            room_name = find_room value
          end
          return room_name if room_name
        end
        nil
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

      include EM::Protocols::LineText2

      def receive_line(data)
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
            @name = json['identified']['name']
          elsif @identified == false and json['display'] == 'error'
            @identification_error = json
          elsif @identified
            save_messages json
            update_name_on_name_change json
          end
        end
      end

      def changing_my_name?(json)
        json['change'] and json['user'] and json['user']['name'] and json['user']['name'].keys.first == @name
      end

      def update_name_on_name_change(json)
        return if json.nil? or json.empty?
        if changing_my_name? json
          @name = json['user']['name'].values.first 
        end
      end

      def name ; @name ; end

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

    def change(change_type, data)
      @connection.send_data({ 'change' => change_type, change_type => data }.to_json + "\n")
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
      @server = @@servers[@cookie]
    end

    def self.servers
      @@servers
    end

    def self.find_server(cookie)
      @@servers[cookie]
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

  def detected_layout
    iphone_user_agent? ? :iphone : :layout
  end

  def iphone_user_agent?
    request.env["HTTP_USER_AGENT"] && request.env["HTTP_USER_AGENT"][/(Mobile\/.+Safari)/]
  end

  def load_bridge
    cookie = request.cookies['jschat-id']
    JsChat::Bridge.find_server cookie
    @bridge = JsChat::Bridge.new(cookie) 
  end

  def load_or_create_bridge
    cookie = request.cookies['jschat-id']

    if cookie.nil? or cookie.empty?
      cookie = JsChat::Bridge.new_cookie
      response.set_cookie 'jschat-id', cookie
      JsChat::Bridge.new_server cookie
    end

    @bridge = JsChat::Bridge.new(cookie) 
    @bridge.setup_connection
  end

  def messages_js(room)
    '[' + @bridge.recent_messages(room).join(", ") + ']';
  end
end

# Identify
get '/' do
  load_bridge

  if @bridge and @bridge.server and @bridge.server.connection.last_room
    redirect "/chat/#{@bridge.server.connection.last_room}" 
  else
    response.set_cookie 'jschat-id', ''
    erb :index, :layout => detected_layout
  end
end

post '/identify' do
  load_or_create_bridge
  @bridge.server.identify params['name']
  @bridge.server.connection.last_room = params['room']
  redirect '/identify-pending'
end

post '/change-name' do
  load_bridge
  @bridge.server.change 'user', { 'name' => params['name'] }
end

# Invalid nick names should be handled using Ajax
get '/identify-pending' do
  load_bridge

  if @bridge.server.identified?
    { 'action' => 'redirect', 'to' => "/chat/#{@bridge.server.connection.last_room}" }.to_json
  elsif @bridge.server.connection.identification_error
    @bridge.server.connection.identification_error.to_json
  else
    # Waiting for a response
    { 'action' => 'reload' }.to_json
  end
end

get '/messages' do
  load_bridge
  if @bridge.nil? or @bridge.server.nil?
    raise "Lost bridge connection"
  else
    @bridge.server.connection.polled
    @bridge.server.connection.last_room = params['room']
    messages_js params['room']
  end
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

  if @bridge and @bridge.server and @bridge.server.identified?
    erb :message_form, :layout => detected_layout
  else
    erb :index, :layout => detected_layout
  end
end

post '/message' do
  load_bridge
  @bridge.server.connection.last_room = params['to']
  @bridge.server.send_message params['message'], params['to']
  # Send messages back to the client
  @bridge.server.connection.polled
  @bridge.server.connection.last_room = params['room']
  messages_js params['room']
end

get '/user/name' do
  load_bridge
  @bridge.server.connection.name
end

get '/quit' do
  load_bridge
  if @bridge and @bridge.server
    @bridge.server.quit
  end
  redirect '/'
end

# This serves the JavaScript concat'd by Sprockets
# run script/sprocket.rb to cache this
get '/javascripts/all.js' do
  root = File.join(File.dirname(File.expand_path(__FILE__)))
  sprockets_config = YAML.load(IO.read(File.join(root, 'config', 'sprockets.yml')))
  secretary = Sprockets::Secretary.new(sprockets_config.merge(:root => root))
  content_type 'text/javascript'
  secretary.concatenation.to_s
end

