require 'test_helper'

class TestJsChat < Test::Unit::TestCase
  include JsChatHelpers

  def setup
    @jschat = JsChatMock.new
    @jschat.post_init
    @cookie = get_cookie 
  end

  def test_identify
    response = send_to_jschat({ 'identify' => 'alex', 'cookie' => @cookie })
    assert_equal 'identified', response['display']
  end

  def test_join
    response = identify_as 'alex2', '#jschat'
    assert JSON.parse(response)['join']
  end

  def test_message
    response = identify_as 'nick', '#jschat'
    assert send_to_jschat({ 'cookie' => @cookie, 'send' => 'hello', 'to' => '#jschat' }, false)
  end

  private

    def get_cookie
      JSON.parse(@jschat.receive_line({ 'protocol' => 'stateless' }.to_json))['cookie']
    end

end
