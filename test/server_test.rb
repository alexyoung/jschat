require 'test/unit'
require 'rubygems'
require 'eventmachine'
require 'json'
require File.join(File.dirname(__FILE__), '../', 'jschat.rb')

ServerConfig = {
  :max_message_length => 500
}

class JsChat::Room
  def self.reset
    @@rooms = nil
  end
end

class JsChatMock
  include JsChat

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

class TestJsChat < Test::Unit::TestCase
  def setup
    @jschat = JsChatMock.new
    @jschat.post_init
  end

  def teardown
    @jschat.reset
  end

  def test_identify
    response = JSON.parse @jschat.receive_data({ 'identify' => 'alex' }.to_json)
    assert_equal 'identified', response['display']
  end

  def test_invalid_identify
    expected = { 'display' => 'error',  'error' => { 'message' => 'Invalid name' } }.to_json + "\n"
    assert_equal expected, @jschat.receive_data({ 'identify' => '@lex' }.to_json)
  end

  def test_ensure_nicks_are_unique
    identify_as 'alex'

    # Obvious duplicate
    result = identify_as 'alex'
    assert result['error']

    # Case
    result = identify_as 'Alex'
    assert result['error']
  end

  def test_invalid_room_name
    identify_as 'bob'
    response = JSON.parse @jschat.receive_data({ 'join' => 'oublinet' }.to_json)
    assert_equal 'Invalid room name', response['error']['message']
  end

  def test_join
    identify_as 'bob'
    expected = { 'display' => 'join', 'join' => { 'user' => 'bob', 'room' => '#oublinet' } }.to_json + "\n"
    assert_equal expected, @jschat.receive_data({ 'join' => '#oublinet' }.to_json)
  end

  def test_join_without_identifying
    response = JSON.parse @jschat.receive_data({ 'join' => '#oublinet' }.to_json)
    assert response['error']
  end

  def test_join_more_than_once
    identify_as 'bob'

    expected = { 'display' => 'error', 'error' => { 'message' => 'Already in that room' } }.to_json + "\n"
    @jschat.receive_data({ 'join' => '#oublinet' }.to_json)
    assert_equal expected, @jschat.receive_data({ 'join' => '#oublinet' }.to_json)
  end

  def test_identify_twice
    identify_as 'nick'
    expected = { 'display' => 'error', 'error' => { 'message' => 'Name already taken' } }.to_json + "\n"
    assert_equal expected, @jschat.receive_data({ 'identify' => 'nick' }.to_json)
  end

  def test_names
    identify_as 'nick', '#oublinet'

    # Add a user
    @jschat.add_user 'alex', '#oublinet'

    response = JSON.parse(@jschat.receive_data({ 'names' => '#oublinet' }.to_json))
    assert response['names']
  end

  def test_valid_names
    user = JsChat::User.new nil
    ['alex*', "alex\n"].each do |name|
      assert_raises JsChat::Errors::InvalidName do
        user.name = name
      end
    end
  end

  def test_message_not_in_room
    identify_as 'nick', '#oublinet'
    @jschat.add_user 'alex', '#oublinet'
    response = JSON.parse @jschat.receive_data({ 'send' => 'hello', 'to' => '#merk' }.to_json)
    assert_equal 'Please join this room first', response['error']['message']
  end

  def test_message
    identify_as 'nick', '#oublinet'
    @jschat.add_user 'alex', '#oublinet'
    assert @jschat.receive_data({ 'send' => 'hello', 'to' => '#oublinet' }.to_json)
  end

  def test_message_ignores_case
    identify_as 'nick', '#oublinet'
    @jschat.add_user 'alex', '#oublinet'
    response = @jschat.receive_data({ 'send' => 'hello', 'to' => '#Oublinet' }.to_json)
    assert response
  end

  def test_part
    identify_as 'nick', '#oublinet'
    @jschat.add_user 'alex', '#oublinet'
    response = JSON.parse @jschat.receive_data({ 'part' => '#oublinet'}.to_json)
    assert_equal '#oublinet', response['part']['room']
  end

  def test_private_message
    identify_as 'nick'
    @jschat.add_user 'alex', '#oublinet'
    response = JSON.parse @jschat.receive_data({ 'send' => 'hello', 'to' => 'alex' }.to_json)
    assert_equal 'hello', response['message']['message']
  end

  def test_private_message_ignores_case
    identify_as 'nick'
    @jschat.add_user 'alex', '#oublinet'
    response = JSON.parse @jschat.receive_data({ 'send' => 'hello', 'to' => 'Alex' }.to_json)
    assert_equal 'hello', response['message']['message']
  end

  def test_log_request
    identify_as 'nick', '#oublinet'
    @jschat.receive_data({ 'send' => 'hello', 'to' => '#oublinet' }.to_json)
    response = JSON.parse @jschat.receive_data({ 'lastlog' => '#oublinet' }.to_json)
    assert_equal 'hello', response['messages'].last['message']['message']
  end

  def test_name_change
    identify_as 'nick', '#oublinet'
    @jschat.add_user 'alex', '#oublinet'
    response = JSON.parse @jschat.receive_data({ 'change' => 'user', 'user' => { 'name' => 'bob' }}.to_json)
    assert_equal 'notice', response['display']
  end

  def test_name_change_duplicate
    identify_as 'nick', '#oublinet'
    @jschat.add_user 'alex', '#oublinet'
    response = JSON.parse @jschat.receive_data({ 'change' => 'user', 'user' => { 'name' => 'alex' }}.to_json)
    assert_equal 'error', response['display']
  end

  def test_max_message_length
    identify_as 'nick', '#oublinet'
    response = JSON.parse @jschat.receive_data({ 'send' => 'a' * 1000, 'to' => '#oublinet' }.to_json)
    assert response['error']
  end

  def test_flood_protection
    identify_as 'nick', '#oublinet'
    response = ''
    # simulate a flood and extract the error response
    (1..50).detect do
      response = @jschat.receive_data({ 'send' => 'a' * 10, 'to' => '#oublinet' }.to_json)
      response.match /error/
    end
    response = JSON.parse response
    assert response['error']
    assert_match /wait a few seconds/i, response['error']['message']
  end

  private

    def identify_as(name, channel = nil)
      result = @jschat.receive_data({ 'identify' => name }.to_json)
      result = @jschat.receive_data({ 'join' => channel }.to_json) if channel
      result
    end
end

