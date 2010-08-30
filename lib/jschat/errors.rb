module JsChat
  class Error < RuntimeError
    def initialize(code_key, message)
      @message = message
      @code = JsChat::Errors::Codes.invert[code_key]
    end

    # Note: This shouldn't really include 'display' directives
    def to_json(*a)
      { 'display' => 'error', 'error' => { 'message' => @message, 'code' => @code } }.to_json(*a)
    end
  end

  module Errors
    class InvalidName < JsChat::Error ; end
    class MessageTooLong < JsChat::Error ; end
    class InvalidCookie < JsChat::Error ; end

    Codes = {
      # 1xx: User errors
      100 => :name_taken,
      101 => :invalid_name,
      104 => :not_online,
      105 => :identity_required,
      106 => :already_identified,
      107 => :invalid_cookie,
      # 2xx: Room errors
      200 => :already_joined,
      201 => :invalid_room,
      202 => :not_in_room,
      204 => :room_not_available,
      # 3xx: Message errors
      300 => :to_required,
      301 => :message_too_long,
      # 5xx: Other errors
      500 => :invalid_request,
      501 => :flooding,
      502 => :ping_out
    }
  end
end
