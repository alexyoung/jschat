require 'rubygems'
require 'sinatra'
require 'sha1'
require 'eventmachine'
require 'json'

puts "*** Must be run in production mode (-e production)"

module JsChat
  class Server
    def initialize(cookie)
      @cookie = cookie
      run
    end

    module EventServer
      def post_init
        puts "post_init"
        @identified = false
        @messages = []
      end

      def identified?
        @identified
      end

      def messages
        @messages
      end

      def room=(room)
        @room = room
      end

      def receive_data(data)
        json = JSON.parse(data)

        puts "LINE FROM SERVER: #{data}"

        if @identified == false and json['name']
          @identified = true
          @name = json['name']
          send_data({'join' => @room}.to_json)
        elsif @identified and json['display'] == 'join'
          puts "JOINED A CHANNEL"
        elsif @identified
          @messages << data
          #if json.has_key?('display') and @protocol.legal? json['display']
          #  @messages << @protocol.send(json['display'], json[json['display']])
          #else
          #  @messages << "* [SERVER] #{data}"
          #end
        end
      end
    end

    def room=(room)
      @connection.room = room
    end

    def identify(name)
      @connection.send_data({'identify' => name}.to_json)
    end

    def identified?
      @connection.identified?
    end

    def run
      @connection = EM.connect '0.0.0.0', 6789, EventServer
    end

    def recent_messages
      messages = @connection.messages.dup
      @connection.messages.clear
      messages
    end
    
    def send_message(message)
      @connection.send_data({ 'to' => '#merk', 'send' => message }.to_json + "\n")
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

    def recent_messages
      @server.recent_messages
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
  def message_form
    html = <<-HTML
      <h2>Server count: #{JsChat::Bridge.servers.length}</h2>
      <ul id="messages">
      </ul>
      <div>
        <form method="post" action="/message" id="post_message">
          Enter message: <input name="message" id="message" value="" type="text" />
        </form>
      </div>
    HTML
  end

  def load_bridge
    cookie = request.cookies['jschat-id']

    if cookie.nil?
      cookie = JsChat::Bridge.new_cookie
      set_cookie 'jschat-id', cookie
      JsChat::Bridge.new_server cookie
    end

    @bridge = JsChat::Bridge.new(cookie) 
  end

  def messages_js
    '[' + @bridge.recent_messages.join(", ") + ']';
  end
end

# Main layout
template :layout do
  <<-HTML
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
	"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
	<title>JsChat</title>
  <script src="http://ajax.googleapis.com/ajax/libs/prototype/1.6.0.3/prototype.js" type="text/javascript"></script>
  <script type="text/javascript">
    var Display = {
      message: function(message) {
        var text = '[\#{room}] (\#{user}) \#{message}';
        return text.interpolate({ room: message['room'], user: message['user'], message: message['message'] });
      }
    };

    function displayMessages(text) {
      var json_set = text.evalJSON(true);
      if (json_set.length == 0) {
        return;
      }
      json_set.each(function(json) {
        var display_text = Display[json['display']](json[json['display']]);
        $('messages').insert({ bottom: '<li>' + display_text + '</li>' });
      });
    }

    function updateMessages() {
      new Ajax.Request('/messages', {
        method: 'get',
        onSuccess: function(transport) {
          displayMessages(transport.responseText);
        }
      });
    }

    document.observe('dom:loaded', function() {
      if ($('post_message')) {
        $('post_message').observe('submit', function(e) {
          var element = Event.element(e);
          var message = $('message').value;
          $('message').value = '';
          new Ajax.Request('/message', {
            method: 'post',
            parameters: { 'message': message },
            onSuccess: function(transport) {
            }
          });

          Event.stop(e);
        });
      }

      if ($('messages')) {
        new PeriodicalExecuter(updateMessages, 3);
      }
    });
  </script>
</head>
<body>
  <%= yield %>
</body>
</html>
  HTML
end

# Identify
get '/' do
  html = <<-HTML
    <form method="post" action="/identify">
      Enter name: <input name="name" id="name" value="" type="text" />
      and room: <input name="room" id="room" value="#merk" type="room" />
      <input type="submit" value="Go" />
    </form> 
  HTML
  erb html
end

post '/identify' do
  load_bridge
  @bridge.server.identify params['name']
  @bridge.server.room = params['room']

  redirect '/identify-pending'
end

get '/identify-pending' do
  load_bridge

  if @bridge.server.identified?
    redirect '/chat'
  else
    "Not identified yet, please refresh"
  end
end

get '/messages' do
  load_bridge
  messages_js
end

get '/chat' do
  load_bridge
  erb message_form
end

post '/message' do
  load_bridge
  @bridge.server.send_message params['message']
  "Message posted"
end
