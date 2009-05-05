require 'rubygems'
require 'eventmachine'
require 'json'

module JsChat
  class User
    attr_accessor :name, :connection, :rooms

    def initialize(connection)
      @name = nil
      @connection = connection
      @rooms = []
    end

    def to_json
      { 'name' => @name }.to_json
    end

    def name=(name)
      if User.valid_name? name
        @name = name
      else
        raise JsChat::Errors::InvalidName.new('Invalid name')
      end
    end

    def self.valid_name?(name)
      not name.match /[^[:alnum:]._\-\[\]^C]/
    end

    def private_message(message)
      response = { 'display' => 'message', 'message' => message }
      @connection.send_response response
    end
  end

  class Room
    attr_accessor :name, :users

    def initialize(name)
      @name = name
      @users = []
    end

    def self.valid_name?(name)
      User.valid_name?(name[1..-1]) and name[0].chr == '#'
    end

    def self.find(item)
      @@rooms ||= []

      if item.kind_of? String
        @@rooms.find { |room| room.name == item }
      elsif item.kind_of? User
        @@rooms.find_all { |room| room.users.include? item }
      end
    end

    def self.find_or_create(room_name)
      room = find room_name
      if room.nil?
        room = new(room_name)
        @@rooms << room
      end
      room
    end

    def lastlog
      { 'display' => 'messages', 'messages' => @messages }
    end

    def add_to_lastlog(message)
      @messages ||= []
      @messages.push message
      @messages = @messages[-100..-1] if @messages.size > 100
    end

    def join(user)
      if @users.include? user
        Error.new('Already in that room')
      else
        @users << user
        user.rooms << self
        join_notice user
        { 'display' => 'join', 'join' => { 'user' => user.name, 'room' => @name } }
      end
    end

    def part(user)
      if not @users.include?(user)
        Error.new('Not in that room')
      else
        user.rooms.delete_if { |r| r == self }
        @users.delete_if { |u| u == user }
        part_notice user
        { 'display' => 'part', 'part' => { 'user' => user.name, 'room' => @name } }
      end
    end

    def send_message(message)
      message['room'] = name
      response = { 'display' => 'message', 'message' => message }

      add_to_lastlog response

      @users.each do |user|
        user.connection.send_response response
      end
    end
    
    def member_names
      @users.collect { |user| user.name }
    end

    def to_json
      { 'name' => @name, 'members' => member_names }.to_json
    end

    def notice(user, message)
      add_to_lastlog message

      @users.each do |u|
        if u != user
          u.connection.send_response(message)
        end
      end
    end

    def join_notice(user)
      notice(user, { 'display' => 'join_notice', 'join_notice' => { 'user' => user.name, 'room' => @name } })
    end

    def part_notice(user)
      notice(user, { 'display' => 'part_notice', 'part_notice' => { 'user' => user.name, 'room' => @name } })
    end

    def quit_notice(user)
      notice(user, { 'display' => 'quit_notice', 'quit_notice' => { 'user' => user.name, 'room' => @name } })
      @users.delete_if { |u| u == user }
    end
  end

  class Error < RuntimeError
    # Note: This shouldn't really include 'display' directives
    def to_json
      { 'display' => 'error', 'error' => { 'message' => message } }.to_json
    end
  end

  module Errors
    class InvalidName < JsChat::Error
    end
  end

  # {"identify":"alex"}
  def identify(name, options = {})
    if @@users.find { |user| user.name == name }
      Error.new("Nick already taken")
    else
      @user.name = name
      { 'display' => 'identified', 'identified' => @user }
    end
  rescue JsChat::Errors::InvalidName => exception
    exception
  end

  def lastlog(room, options = {})
    room = Room.find room

    if room and room.users.include? @user
      room.lastlog
    else
      Error.new("Please join this room first")
    end
  end

  def room_message(message, options)
    room = Room.find options['to']

    if room and room.users.include? @user
      room.send_message({ 'message' => message, 'user' => @user.name })
    else
      send_response Error.new("Please join this room first")
    end
  end

  def private_message(message, options)
    user = @@users.find { |u| u.name == options['to'] }

    if user
      # Return the message to the user, and send it to the other person too
      user.private_message({ 'message' => message, 'user' => @user.name })
      @user.private_message({ 'message' => message, 'user' => @user.name })
    else
      Error.new('User not online')
    end
  end

  def send_message(message, options)
    if options['to'].nil?
      send_response Error.new('Please specify who to send the message to or join a channel')
    elsif options['to'][0].chr == '#'
      room_message message, options
    else
      private_message message, options
    end
  end

  def join(room_name, options = {})
    if Room.valid_name? room_name
      room = Room.find_or_create(room_name)
      room.join @user
    else
      Error.new('Invalid room name')
    end
  end

  def part(room_name, options = {})
    room = @user.rooms.find { |r| r.name == room_name }
    if room
      room.part @user
    else
      Error.new("You are not in that room")
    end
  end

  def names(room_name, options = {})
    room = Room.find(room_name)
    if room
      { 'display' => 'names', 'names' => room.users.collect { |user| user.name } }
    else
      Error.new('No such room')
    end
  end

  def unbind
    # TODO: Remove user from rooms and remove connection
    puts "Removing a connection"
    Room.find(@user).each do |room|
      room.quit_notice @user
    end

    @@users.delete_if { |user| user == @user }
    @user = nil
  end

  def post_init
    @@users ||= []
    @user = User.new(self)
    @@users << @user
  end

  def log(level, message)
    if Object.const_defined? :ServerConfig
      if @user
        message = "#{@user.name}: #{message}"
      end
      ServerConfig[:logger].send level, message
    end
  end

  def send_response(data)
    response = ''
    case data
      when String
        response = data
      when Error
        response = data.to_json + "\n"
        log :error, data.message
      else
        # Other objects should be safe for to_json
        response = data.to_json + "\n"
        log :info, response.strip
    end
    
    send_data response
  end

  def receive_data(data)
    data.split("\n").each do |data|
      # Receive the identify request
      input = JSON.parse data

      if input.has_key? 'identify'
        send_response identify(input['identify'])
      else
        ['lastlog', 'change', 'send', 'join', 'names', 'part'].each do |command|
          if @user.name.nil?
            return send_response(Error.new("Identify first"))
          end

          if input.has_key? command
            if command == 'send'
              return send('send_message', input[command], input)
            else
              return send_response(send(command, input[command], input))
            end
          end
        end
      end
    end
  rescue Exception => exception
    p data
    puts exception
  end
end

