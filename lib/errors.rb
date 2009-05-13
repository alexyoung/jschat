module JsChat
  class Error < RuntimeError
    # Note: This shouldn't really include 'display' directives
    def to_json
      { 'display' => 'error', 'error' => { 'message' => message } }.to_json
    end
  end

  module Errors
    class InvalidName < JsChat::Error ; end
    class MessageTooLong < JsChat::Error ; end
  end
end
