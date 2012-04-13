require 'test/unit'
require 'rubygems'
require 'eventmachine'
gem 'json', '>= 1.1.9'
require 'json'
$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require File.join(File.dirname(__FILE__), '..', 'lib', 'jschat', 'server.rb')

ServerConfig['max_message_length'] = 500

class JsChat::Room
  def self.reset
    @@rooms = nil
  end
end

module JsChatHelpers
  def identify_as(name, channel = nil)
    if @cookie
      result = @jschat.receive_line({ 'identify' => name, :cookie => @cookie }.to_json)
      result = @jschat.receive_line({ 'join' => channel, :cookie => @cookie }.to_json) if channel
    else
      result = @jschat.receive_line({ 'identify' => name }.to_json)
      result = @jschat.receive_line({ 'join' => channel }.to_json) if channel
    end
    result
  end

  def send_to_jschat(h, parse = true)
    response = @jschat.receive_line(h.to_json)
    parse ? JSON.parse(response) : response
  end
end

class JsChatMock
  include JsChat

  def get_remote_ip
    ''
  end

  def send_data(data)
    data
  end

  def reset
    @@users = nil
    @user = nil
    Room.reset
  end

  # Helper for testing
  def add_user(name, room_name)
    room = Room.find_or_create room_name
    user = User.new self
    user.name = name
    user.rooms << room
    @@users << user
    room.users << user
  end
end

JsChat::Storage.enabled = false
JsChat::Storage.driver = JsChat::Storage::NullDriver

