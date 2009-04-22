require 'test/unit'
require 'rubygems'
require 'eventmachine'
require 'json'
require File.join(File.dirname(__FILE__), '../', 'jschat.rb')

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

