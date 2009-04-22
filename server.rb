#!/usr/bin/env ruby

require 'jschat'

ServerConfig = {
  :port => 6789,
  :ip => '0.0.0.0'
}

EM.run do
  EM.start_server ServerConfig[:ip], ServerConfig[:port], JsChat
end

