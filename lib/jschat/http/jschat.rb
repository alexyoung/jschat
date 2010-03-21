require 'rubygems'
require 'sinatra'
require 'sha1'
require 'json'
require 'sprockets'

set :public, File.join(File.dirname(__FILE__), 'public')
set :views, File.join(File.dirname(__FILE__), 'views')

module JsChat
  Config = {
    :ip   => '0.0.0.0',
    :port => 6789
  }

  class ConnectionError < Exception ; end
end

# todo: can this be async and allow the server to have multiple threads? 
class JsChat::Bridge
  attr_reader :cookie, :identification_error, :last_error

  def initialize(cookie = nil)
    @cookie = cookie
  end

  def cookie_set?
    !(@cookie.nil? or @cookie.empty?)
  end

  def connect
    response = send_json({ :protocol => 'stateless' })
    @cookie = response['cookie']
  end

  def identify(name, ip)
    response = send_json({ :identify => name, :ip => ip })
    if response['display'] == 'error'
      @identification_error = response
      false
    else
      true
    end
  end

  def lastlog(room)
    response = send_json({ :lastlog => room })
    response['messages']
  end

  def recent_messages(room)
    send_json({ 'since' => room })['messages']
  end

  def join(room)
    send_json({ :join => room }, false)
  end

  def send_message(message, to)
    send_json({ :send => message, :to => to }, false)
  end

  def active?
    return false unless cookie_set?
    response = ping
    if response.nil? or response['display'] == 'error'
      @last_error = response
      false
    else
      true
    end
  end

  def ping
    send_json({ 'ping' => Time.now.utc })
  end

  def change(change_type, data)
    send_json({ 'change' => change_type, change_type => data })
  end

  def names(room)
    send_json({'names' => room})
  end

  def send_quit(name)
    send_json({'quit' => name })
  end

  def send_json(h, get_results = true)
    response = nil
    h[:cookie] = @cookie if cookie_set?
    c = TCPSocket.open(JsChat::Config[:ip], JsChat::Config[:port])
    c.send(h.to_json + "\n", 0)
    if get_results
      response = c.gets
      response = JSON.parse(response)
    end
  ensure
    c.close
    response
  end
end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html

  def detected_layout
    iphone_user_agent? ? :iphone : :layout
  end

  def iphone_user_agent?
    request.env["HTTP_USER_AGENT"] && request.env["HTTP_USER_AGENT"][/(Mobile\/.+Safari)/]
  end

  def load_bridge
    @bridge = JsChat::Bridge.new request.cookies['jschat-id']
  end

  def load_and_connect
    @bridge = JsChat::Bridge.new request.cookies['jschat-id']
    @bridge.connect
    response.set_cookie 'jschat-id', @bridge.cookie
  end

  def save_last_room(room)
    response.set_cookie 'last-room', room
  end

  def last_room
    request.cookies['last-room']
  end

  def save_nickname(name)
    response.set_cookie 'jschat-name', name
  end

  def messages_js(messages)
    messages ||= []
    messages.to_json
  end

  def remove_my_messages(messages)
    return if messages.nil?
    messages.delete_if { |message| message['message'] and message['message']['user'] == nickname }
  end

  def clear_cookies
    response.set_cookie 'last-room', nil
    response.set_cookie 'jschat-id', nil
  end

  def nickname
    request.cookies['jschat-name']
  end
end

# Identify
get '/' do
  load_bridge

  if @bridge.active? and last_room
    redirect "/chat/#{last_room}" 
  else
    clear_cookies
    erb :index, :layout => detected_layout
  end
end

post '/identify' do
  load_and_connect
  save_last_room params['room']
  save_nickname params['name']
  if @bridge.identify params['name'], request.ip
    { 'action' => 'redirect', 'to' => "/chat/#{params['room']}" }.to_json
  else
    @bridge.identification_error.to_json
  end
end

post '/change-name' do
  load_bridge
  [@bridge.change('user', { 'name' => params['name'] })].to_json
end

get '/messages' do
  load_bridge
  if @bridge.active?
    save_last_room params['room']
    messages_js remove_my_messages(@bridge.recent_messages(params['room']))
  else
    if @bridge.last_error and @bridge.last_error['error']['code'] == 107
      error 500, [@bridge.last_error].to_json 
    else
      [@bridge.last_error].to_json
    end
  end
end

get '/names' do
  load_bridge
  save_last_room params['room']
  [@bridge.names(params['room'])].to_json
end

get '/lastlog' do
  load_bridge
  if @bridge.active?
    save_last_room params['room']
    messages_js @bridge.lastlog(params['room'])
  end
end

post '/join' do
  load_bridge
  @bridge.join params['room']
  save_last_room params['room']
  "Request OK"
end

get '/chat/' do
  load_bridge
  if @bridge and @bridge.active?
    erb :message_form, :layout => detected_layout
  else
    erb :index, :layout => detected_layout
  end
end

post '/message' do
  load_bridge
  save_last_room params['room']
  @bridge.send_message params['message'], params['to']
  'OK'
end

get '/user/name' do
  load_bridge
  nickname
end

get '/ping' do
  load_bridge
  @bridge.ping.to_json
end

get '/quit' do
  load_bridge
  @bridge.send_quit nickname
  load_bridge
  clear_cookies
  redirect '/'
end

# This serves the JavaScript concat'd by Sprockets
# run script/sprocket.rb to cache this
get '/javascripts/all.js' do
  root = File.join(File.dirname(File.expand_path(__FILE__)))
  sprockets_config = YAML.load(IO.read(File.join(root, 'config', 'sprockets.yml')))
  secretary = Sprockets::Secretary.new(sprockets_config.merge(:root => root))
  content_type 'text/javascript'
  secretary.concatenation.to_s
end
