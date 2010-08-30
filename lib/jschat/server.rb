require 'rubygems'
require 'eventmachine'
gem 'json', '>= 1.1.9'
require 'json'
require 'time'
require 'socket'

# JsChat libraries
require 'jschat/init'
require 'jschat/errors'
require 'jschat/flood_protection'

module JsChat
  module Server
    def self.pid_file_name
      File.join(ServerConfig['tmp_files'], 'jschat.pid')
    end

    def self.write_pid_file
      return unless ServerConfig['use_tmp_files']
      File.open(pid_file_name, 'w') { |f| f << Process.pid }
    end

    def self.rm_pid_file
      FileUtils.rm pid_file_name
    end

    def self.stop
      rm_pid_file
    end

    def self.run!
      write_pid_file
      JsChat.init_storage

      at_exit do
        stop
      end

      EM.run do
        EM.start_server ServerConfig['ip'], ServerConfig['port'], JsChat
      end
    end
  end

  class User
    include JsChat::FloodProtection

    attr_accessor :name, :connection, :rooms, :last_activity,
                  :identified, :ip, :last_poll, :session_length

    def initialize(connection)
      @name = nil
      @connection = connection
      @rooms = []
      @last_activity = Time.now.utc
      @last_poll = Time.now.utc
      @identified = false
      @ip = ''
      @expires = nil
      @session_length = nil
    end

    def session_expired?
      return true if @expires.nil?
      Time.now.utc >= @expires
    end

    def update_session_expiration
      return if @session_length.nil?
      @expires = Time.now.utc + @session_length
    end

    def to_json(*a)
      { 'name' => @name, 'last_activity' => @last_activity }.to_json(*a)
    end

    def name=(name)
      if @connection and @connection.name_taken? name
        raise JsChat::Errors::InvalidName.new(:name_taken, 'Name taken')
      elsif User.valid_name?(name)
        @identified = true
        @name = name
      else
        raise JsChat::Errors::InvalidName.new(:invalid_name, 'Invalid name')
      end
    end

    def self.valid_name?(name)
      not name.match /[^[:alnum:]._\-\[\]^C]/ and name.size > 0
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

    def self.rooms
      @@rooms
    end

    def lastlog(since = nil)
      { 'display' => 'messages', 'messages' => messages_since(since) }
    end

    def search(query, limit = 100)
      { 'display' => 'messages', 'messages' => message_search(query, limit) }
    end

    def last_update_time
      message = JsChat::Storage.driver.lastlog(LASTLOG_DEFAULT, name).last
      message['time'] if message
    end

    def messages_since(since)
      messages = JsChat::Storage.driver.lastlog(LASTLOG_DEFAULT, name)
      if since.nil?
        messages
      else
        messages.select { |m| m['time'] && m['time'] > since }
      end
    end

    def message_search(query, limit)
      JsChat::Storage.driver.search(query, name, limit)
    end

    def add_to_lastlog(message)
      if message
        message['time'] = Time.now.utc
        JsChat::Storage.driver.log message, name
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

    def to_json(*a)
      { 'name' => @name, 'members' => member_names }.to_json(*a)
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
  def identify(name, ip, session_length, options = {})
    if @user and @user.identified
      Error.new :already_identified, 'You have already identified'
    elsif name_taken? name
      Error.new :name_taken, 'Name already taken'
    else
      @user.name = name
      @user.ip = ip
      @user.session_length = session_length
      @user.update_session_expiration
      register_stateless_user if @stateless
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

  def search(query, options = {})
    room = Room.find options['room']
    if room and room.users.include? @user
      room.search query
    else
      Error.new(:not_in_room, "Please join this room first")
    end
  end

  def since(room, options = {})
    room = Room.find room
    if room and room.users.include? @user
      response = room.lastlog(@user.last_poll)
      @user.last_poll = Time.now.utc
      response
    else
      Error.new(:not_in_room, "Please join this room first")
    end
  end

  def times(message, options = {})
    times = {}
    @user.rooms.each do |room|
      times[room.name] = room.last_update_time
    end
    times
  end

  def ping(message, options = {})
    if @user and @user.last_poll and Time.now.utc > @user.last_poll
      time = Time.now.utc
      @user.update_session_expiration
      { 'pong' => time }
    else
      # TODO: HANDLE PING OUTS
      Error.new(:ping_out, 'Your connection has been lost')
    end
  end

  def quit(message, options = {})
    if @user
      disconnect_user @user
    end
  end

  def room_message(message, options)
    room = Room.find options['to']
    if room and room.users.include? @user
      room.send_message({ 'message' => message, 'user' => @user.name })
    else
      send_response Error.new(:not_in_room, "Please join this room first")
    end
  end

  def private_message(message, options)
    user = users_with_names.find { |u| u.name.downcase == options['to'].downcase }
    if user
      # Return the message to the user, and send it to the other person too
      now = Time.now.utc
      user.private_message({ 'message' => message, 'user' => @user.name })
      @user.private_message({ 'message' => message, 'user' => @user.name })
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

  def new_cookie
    chars = ("a".."z").to_a + ("1".."9").to_a 
    Array.new(8, '').collect { chars[rand(chars.size)] }.join
  end

  def register_stateless_client
    @stateless_cookie = new_cookie
    user = User.new(self)
    @@stateless_cookies << { :cookie => @stateless_cookie, :user => user }
    @@users << user
    { 'cookie' => @stateless_cookie }
  end

  def current_stateless_client
    @@stateless_cookies.find { |c| c[:cookie] == @stateless_cookie }
  end

  def register_stateless_user
    current_stateless_client[:user] = @user
  end

  def valid_stateless_user?
    current_stateless_client 
  end

  def load_stateless_user
    if client = current_stateless_client
      @user = client[:user]
      @stateless = true
    else
      raise JsChat::Errors::InvalidCookie.new(:invalid_cookie, 'Invalid cookie')
    end
  end

  def disconnect_lagged_users
    @@stateless_cookies.delete_if do |cookie|
      if cookie[:user].session_expired?
        lagged?(cookie[:user].last_poll) ? disconnect_user(cookie[:user]) && true : false
      end
    end
  end

  def lagged?(time)
    Time.now.utc - time > STATELESS_TIMEOUT
  end

  def unbind
    return if @stateless
    disconnect_user(@user)
    @user = nil
  end

  def disconnect_user(user)
    log :info, "Removing a connection"
    Room.find(user).each do |room|
      room.quit_notice user
    end

    @@users.delete_if { |u| u == user }
  end

  def post_init
    @@users ||= []
    @@stateless_cookies ||= []
    @user = User.new(self)
  end

  def log(level, message)
    if Object.const_defined? :ServerConfig and ServerConfig['logger']
      if @user
        message = "#{@user.name} (#{@user.ip}): #{message}"
      end
      ServerConfig['logger'].send level, message
    end
  end

  def change(change, options = {})
    if change == 'user'
      field, value = @user.send :change, options[change]
      { 'display' => 'notice', 'notice' => "Your #{field} has been changed to: #{value}" }
    else
      Error.new(:invalid_request, 'Invalid change request')
    end
  rescue JsChat::Errors::InvalidName => exception
    exception
  end

  def list(list, options = {})
    case list
      when 'rooms'
        @user.rooms.collect { |room| room.name }
    else
      Error.new(:invalid_request, 'Invalid list command')
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

  include EM::Protocols::LineText2

  def get_remote_ip
    Socket.unpack_sockaddr_in(get_peername)[1]
  end

  def receive_line(data)
    response = ''
    disconnect_lagged_users

    if data and data.size > ServerConfig['max_message_length']
      raise JsChat::Errors::MessageTooLong.new(:message_too_long, 'Message too long')
    end

    data.chomp.split("\n").each do |line|
      # Receive the identify request
      input = JSON.parse line 

      @user.seen!

      # Unbind when a stateless connection doesn't match the cookie
      if input.has_key?('cookie')
        @stateless_cookie = input['cookie']
        load_stateless_user
      end

      if input.has_key? 'protocol'
        if input['protocol'] == 'stateless'
          @stateless = true
          response << send_response(register_stateless_client)
        end
      elsif input.has_key? 'identify'
        input['ip'] ||= get_remote_ip
        response << send_response(identify(input['identify'], input['ip'], input['session_length']))
      else
        %w{search lastlog change send join names part since ping list quit times}.each do |command|
          if @user.name.nil?
            response << send_response(Error.new(:identity_required, 'Identify first'))
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
  rescue JsChat::Errors::InvalidCookie => exception
    send_response exception
  rescue Exception => exception
    puts "Data that raised exception: #{exception}"
    p data
    print_call_stack
  end

  def print_call_stack(from = 0, to = 10)
    puts "Stack:"
    (from..to).each do |index|
      puts "\t#{caller[index]}"
    end  
  end  
end
