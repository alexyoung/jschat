#!/usr/bin/env ruby

require 'logger'
require 'jschat'

logger = Logger.new(STDERR)
logger = Logger.new(STDOUT)

ServerConfig = {
  :port => 6789,
  :ip => '0.0.0.0',
  :logger => logger,
  :max_message_length => 500
}

EM.run do
  EM.start_server ServerConfig[:ip], ServerConfig[:port], JsChat
end

