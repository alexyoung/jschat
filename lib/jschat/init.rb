module JsChat ; end

require 'jschat/server_options'
require 'jschat/storage/init'

module JsChat
  STATELESS_TIMEOUT = 60
  LASTLOG_DEFAULT = 100

  def self.init_storage
    if JsChat::Storage::MongoDriver.available?
      JsChat::Storage.enabled = true
      JsChat::Storage.driver = JsChat::Storage::MongoDriver
    else
      JsChat::Storage.enabled = false
      JsChat::Storage.driver = JsChat::Storage::NullDriver
    end
  end
end
