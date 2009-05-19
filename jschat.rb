require 'rubygems'
require 'eventmachine'
require 'json'
require 'time'

# JsChat libraries
require 'lib/errors'
require 'lib/flood_protection'

module JsChat
  class User
    include JsChat::FloodProtection

    attr_accessor :name, :connection, :rooms, :last_activity

    def initialize(connection)
      @name = nil
      @connection = connection
      @rooms = []
      @last_activity = Time.now.utc
    end

    def to_json
      { 'name' => @name, 'last_activity' => @last_activity }.to_json
    end

    def name=(name)
      if @connection and @connection.name_taken? name
        raise JsChat::Errors::InvalidName.new(:name_taken, 'Name taken')
      elsif User.valid_name?(name)
        @name = name
      else
        raise JsChat::Errors::InvalidName.new(:invalid_name, 'Invalid name')
      end
    end

    def self.valid_name?(name)
      not name.match /[^[:alnum:]._\-\[\]^C]/
    end

    def private_message(message)
      response = { 'display' => 'message', 'message' => message }
      @connection.send_response response
    end

    def change(params)
      # Valid options for change
      ['name'].each do |field|
        if params[field]
          old_value = send(field)
          send "#{field}=", params[field]
          @rooms.each do |room|
            response = { 'change' => 'user',
                         'room' => room.name,
                         'user' => { field => { old_value => params[field] } } }
            room.change_notice self, response
            return [field, params[field]]
          end
        end
      end
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
        @@rooms.find { |room| room.name.downcase == item.downcase if room.name }
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
      if message
        if message.has_key? 'display'
          message[message['display']]['time'] = Time.now.utc
        elsif message.has_key? 'change'
          message[message['change']]['time'] = Time.now.utc
        end
        @messages.push message
        @messages = @messages[-100..-1] if @messages.size > 100
      end
    end

    def join(user)
      if @users.include? user
        Error.new(:already_joined, 'Already in that room')
      else
        @users << user
        user.rooms << self
        join_notice user
        { 'display' => 'join', 'join' => { 'user' => user.name, 'room' => @name } }
      end
    end

    def part(user)
      if not @users.include?(user)
        Error.new(:not_in_room, 'Not in that room')
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

    def notice(user, message, all = false)
      add_to_lastlog message

      @users.each do |u|
        if (u != user and !all) or all
          u.connection.send_response(message)
        end
      end
    end

    def change_notice(user, response)
      notice(user, response, true)
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

  # User initially has a nil name
  def users_with_names
    @@users.find_all { |u| u.name }
  end

  def name_taken?(name)
    users_with_names.find { |user| user.name.downcase == name.downcase }
  end

  # {"identify":"alex"}
  def identify(name, options = {})
    if name_taken? name
      Error.new(:name_taken, 'Name already taken')
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
      Error.new(:not_in_room, "Please join this room first")
    end
  end

  def room_message(message, options)
    room = Room.find options['to']

    if room and room.users.include? @user
      room.send_message({ 'message' => message, 'user' => @user.name, 'time' => Time.now.utc })
    else
      send_response Error.new(:not_in_room, "Please join this room first")
    end
  end

  def private_message(message, options)
    user = users_with_names.find { |u| u.name.downcase == options['to'].downcase }

    if user
      # Return the message to the user, and send it to the other person too
      now = Time.now.utc
      user.private_message({ 'message' => message, 'user' => @user.name, 'time' => now })
      @user.private_message({ 'message' => message, 'user' => @user.name, 'time' => now })
    else
      Error.new(:not_online, 'User not online')
    end
  end

  def send_message(message, options)
    if options['to'].nil?
      send_response Error.new(:to_required, 'Please specify who to send the message to or join a channel')
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
      Error.new(:invalid_room, 'Invalid room name')
    end
  end

  def part(room_name, options = {})
    room = @user.rooms.find { |r| r.name == room_name }
    if room
      room.part @user
    else
      Error.new(:not_in_room, "You are not in that room")
    end
  end

  def names(room_name, options = {})
    room = Room.find(room_name)
    if room
      { 'display' => 'names', 'names' => room.users, 'room' => room.name }
    else
      Error.new(:room_not_available, 'No such room')
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
    if Object.const_defined? :ServerConfig and ServerConfig[:logger]
      if @user
        message = "#{@user.name}: #{message}"
      end
      ServerConfig[:logger].send level, message
    end
  end

  def change(change, options = {})
    if change == 'user'
      field, value = @user.send :change, options[change]
      { 'display' => 'notice', 'notice' => "Your #{field} has been changed to: #{value}" }
    else
      Error.new(:invalid_request, "Invalid change request")
    end
  rescue JsChat::Errors::InvalidName => exception
    exception
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
    response = ''

    if data and data.size > ServerConfig[:max_message_length]
      raise JsChat::Errors::MessageTooLong.new(:message_too_long, 'Message too long')
    end

    data.chomp.split("\n").each do |line|
      # Receive the identify request
      input = JSON.parse line 

      @user.seen!

      if input.has_key? 'identify'
        response << send_response(identify(input['identify']))
      else
        ['lastlog', 'change', 'send', 'join', 'names', 'part'].each do |command|
          if @user.name.nil?
            response << send_response(Error.new(:identity_required, "Identify first"))
            return response
          end

          if input.has_key? command
            if command == 'send'
              @user.last_activity = Time.now.utc
              message_result = send('send_message', input[command], input)
              response << message_result if message_result.kind_of? String
            else
              result = send_response(send(command, input[command], input))
              response << result if result.kind_of? String
            end
          end
        end
      end
    end

    response
  rescue JsChat::Errors::StillFlooding
    ""
  rescue JsChat::Errors::Flooding => exception
    send_response exception
  rescue JsChat::Errors::MessageTooLong => exception
    send_response exception
  rescue Exception => exception
    puts "Data that raised exception: #{exception}"
    p data
    print_call_stack
  end

  def print_call_stack(from = 2, to = 5)
    puts "Stack:"
    (from..to).each do |index|
      puts "\t#{caller[index]}"
    end  
  end  
end
