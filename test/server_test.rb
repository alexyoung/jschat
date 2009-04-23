require 'test/unit'
require 'rubygems'
require 'eventmachine'
require 'json'
require File.join(File.dirname(__FILE__), '../', 'jschat.rb')

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
    expected = { 'name' => 'alex' }.to_json + "\n"
    assert_equal expected, @jschat.receive_data({ 'identify' => 'alex' }.to_json)
  end

  def test_invalid_identify
    expected = { 'error' => 'Invalid name' }.to_json + "\n"
    assert_equal expected, @jschat.receive_data({ 'identify' => '@lex' }.to_json)
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

  def test_names
    @jschat.receive_data({ 'identify' => 'nick' }.to_json)
    @jschat.receive_data({ 'join' => '#oublinet' }.to_json)

    # Add a user
    @jschat.add_user 'alex', '#oublinet'

    expected = { 'names' => ['nick', 'alex'] }.to_json + "\n"
    assert_equal expected, @jschat.receive_data({ 'names' => '#oublinet' }.to_json)
  end

  def test_valid_names
    user = JsChat::User.new nil
    ['alex*', "alex\n"].each do |name|
      assert_raises JsChat::Errors::InvalidName do
        user.name = name
      end
    end
  end
end

