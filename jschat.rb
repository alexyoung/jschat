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
      if valid_name? name
        @name = name
      else
        raise JsChat::Errors::InvalidName.new('Invalid name')
      end
    end

    def valid_name?(name)
      not name.match /[^[:alnum:]._\-\[\]^C]/
    end

    def private_message(message)
      response = { 'display' => 'message', 'message' => message }
      @connection.send_data response.to_json + "\n"
    end
  end

  class Room
    attr_accessor :name, :users

    def initialize(name)
      @name = name
      @users = []
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

    def join(user)
      if @users.include? user
        Error.new('Already in that room').to_json
      else
        @users << user
        user.rooms << self
        join_notice user
        { 'display' => 'join', 'join' => { 'user' => user.name, 'room' => @name } }.to_json
      end
    end

    def part(user)
      if not @users.include?(user)
        Error.new('Not in that room').to_json
      else
        user.rooms.delete_if { |r| r == self }
        @users.delete_if { |u| u == user }
        part_notice user
        { 'display' => 'part', 'part' => { 'user' => user.name, 'room' => @name } }.to_json
      end
    end

    def send_message(message)
      message['room'] = name
      response = { 'display' => 'message', 'message' => message }

      @users.each do |user|
        user.connection.send_data response.to_json + "\n"
      end
    end
    
    def member_names
      @users.collect { |user| user.name }
    end

    def to_json
      { 'name' => @name, 'members' => member_names }.to_json
    end

    def notice(user, message)
      @users.each do |u|
        if u != user
          u.connection.send_data(message + "\n")
        end
      end
    end

    def join_notice(user)
      notice(user, { 'display' => 'join', 'join' => { 'user' => user.name, 'room' => @name } }.to_json)
    end

    def part_notice(user)
      notice(user, { 'display' => 'part', 'part' => { 'user' => user.name, 'room' => @name } }.to_json)
    end

    def quit_notice(user)
      notice(user, { 'display' => 'quit', 'quit' => { 'user' => user.name, 'room' => @name } }.to_json)
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
      Error.new("Nick already taken").to_json
    else
      @user.name = name
      @user.to_json
    end
  rescue JsChat::Errors::InvalidName => exception
    exception.to_json
  end

  def room_message(message, options)
    room = Room.find options['to']

    if room and room.users.include? @user
      room.send_message({ 'message' => message, 'user' => @user.name })
    else
      Error.new("Please join this room first").to_json
    end
  end

  def private_message(message, options)
    user = @@users.find { |u| u.name == options['to'] }

    if user
      # Return the message to the user, and send it to the other person too
      user.private_message({ 'message' => message, 'user' => @user.name })
      @user.private_message({ 'message' => message, 'user' => @user.name })
    else
      Error.new('User not online').to_json
    end
  end

  def send_message(message, options)
    if options['to'].chars.first == '#'
      room_message message, options
    else
      private_message message, options
    end
  end

  def join(room_name, options = {})
    room = Room.find_or_create(room_name)
    room.join @user
  end

  def part(room_name, options = {})
    room = @user.rooms.find { |r| r.name == room_name }
    if room
      room.part @user
    else
      Error.new("You are not in that room").to_json
    end
  end

  def names(room_name, options = {})
    room = Room.find(room_name)
    if room
      { 'display' => 'names', 'names' => room.users.collect { |user| user.name } }.to_json
    else
      Error.new('No such room').to_json
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

  def receive_data(data)
    # Receive the identify request
    input = JSON.parse data

    if input.has_key? 'identify'
      send_data identify(input['identify']) + "\n"
    else
      ['change', 'send', 'join', 'names', 'part'].each do |command|
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

