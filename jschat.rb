require 'rubygems'
require 'eventmachine'
require 'json'

module JsChat
  class User
    attr_accessor :name, :connection

    def initialize(connection)
      @name = nil
      @connection = connection
    end

    def to_json
      { 'name' => @name }.to_json
    end

    def private_message(message, from)
    end
  end

  class Room
    attr_accessor :name, :users

    def initialize(name)
      @name = name
      @users = []
    end

    def self.find(room_name)
      @@rooms ||= []
      @@rooms.find { |room| room.name == room_name }
    end

    def self.find_or_create(room_name)
      room = find room_name
      if room.nil?
        room = new(room_name)
        @@rooms << room
      end
      room
    end

    def send_message(message)
      message['room'] = name

      @users.each do |user|
        user.connection.send_data message.to_json + "\n"
      end
    end
    
    def to_json
      { 'name' => @name }.to_json
    end
  end

  class Error
    def initialize(message)
      @message = message
    end

    def to_s
      @message
    end

    def to_json
      { 'error' => @message }.to_json
    end
  end

  # {"identify":"alex"}
  def identify(name, options = {})
    if @@users.find { |user| user.name == name }
      Error.new("Nick already taken").to_json
    else
      @user.name = name
      @user.to_json
    end
  end

  def change(operator, options)
  end

  # {"to"=>"#merk", "send"=>"hello"}
  def send_message(message, options)
    room = Room.find options['to']
    room.send_message({ 'message' => message, 'user' => @user.name })
  end

  # {"join":"#merk"}
  def join(room_name, options = {})
    room = Room.find_or_create(room_name)
    room.users << @user
    room.to_json
  end

  def unbind
    # TODO: Remove user from rooms and remove connection
    puts "Removing a connection"
    @@users.delete_if { |user| user == @user }
    @user = nil
  end

  def post_init
    @@users ||= []
    @user = User.new(self)
    @@users << @user
  end

  def receive_data(data)
    # Receive the identify request
    input = JSON.parse data

    if input.has_key? 'identify'
      send_data identify(input['identify']) + "\n"
    else
      ['change', 'send', 'join'].each do |command|
        if @user.name.nil?
          return send_data(Error.new("Identify first").to_json + "\n")
        end

        if input.has_key? command
          if command == 'send'
            return send('send_message', input[command], input)
          else
            return send_data(send(command, input[command], input) + "\n")
          end
        end
      end
    end
  rescue Exception => exception
    puts exception
  end
end

<<<<<<< HEAD:jschat.rb
=======
module JsClient
  module KeyboardInput
    include EM::Protocols::LineText2

    def receive_line(line)
      operand = strip_command line
      case line
        when %r{/nick}
          @connection.send_identify operand
        when %r{/join}
          @connection.send_join operand
        else
          @connection.send_message(line)
        end
    end

    def strip_command(line)
      if line.match %r{^/}
        line.match(%r{/[a-zA-Z][^ ]*(.*)})[1].strip
      else
        line
      end
    end

    def connection=(connection)
      @connection = connection
    end
  end

  def receive_data(data)
    json = JSON.parse(data)
    if json.has_key? 'message'
      puts "#{json['room']} <#{json['user']}> #{json['message']}"
    else
      puts "[server] #{data}"
    end
  end

  def send_join(channel)
    @current_channel = channel
    send_data({ 'join' => channel }.to_json)
  end

  def send_message(line)
    send_data({ 'to' => @current_channel, 'send' => line }.to_json + "\n")
  end

  def send_identify(username)
    send_data({ 'identify' => username }.to_json + "\n")
  end
end

if ARGV.first == 'test'
  require 'test/unit'
  
  class JsChatMock
    include JsChat

    def send_data(data)
      data
    end
  end

  class TestJsChat < Test::Unit::TestCase
    def setup
      @jschat = JsChatMock.new
      @jschat.post_init
    end

    def test_identify
      expected = { 'name' => 'alex' }.to_json + "\n"
      assert_equal expected, @jschat.receive_data({ 'identify' => 'alex' }.to_json)
    end

    def test_join
      expected = { 'name' => '#oublinet' }.to_json + "\n"
      @jschat.receive_data({ 'identify' => 'bob' }.to_json)
      assert_equal expected, @jschat.receive_data({ 'join' => '#oublinet' }.to_json)
    end

    def test_join_without_identifying
      expected = { 'error' => 'Identify first' }.to_json + "\n"
      assert_equal expected, @jschat.receive_data({ 'join' => '#oublinet' }.to_json)
    end

    def test_identify_twice
      @jschat.receive_data({ 'identify' => 'nick' }.to_json)
      expected = { 'error' => 'Nick already taken' }.to_json + "\n"
      assert_equal expected, @jschat.receive_data({ 'identify' => 'nick' }.to_json)
    end
  end
elsif ARGV.first == 'client'
  EM.run do
    server = ARGV[1] || '0.0.0.0'
    connection = EM.connect server, port, JsClient
    EM.open_keyboard(JsClient::KeyboardInput) do |keyboard|
      keyboard.connection = connection
    end
  end
else
  EM.run do
    EM.start_server '0.0.0.0', port, JsChat
  end
end

>>>>>>> 877c36218e4e02f85c68f35e32fa28ab7cd579cb:jschat.rb
