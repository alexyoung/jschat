require 'rubygems'
require 'sinatra'

set :environment, :production

# You could log like this:
# log = File.new(File.join(File.dirname(__FILE__), 'sinatra.log'), 'a')
# $stdout.reopen(log)
# $stderr.reopen(log)

require 'jschat.rb'
run Sinatra::Application
