module JsChat::Storage
  MEMORY_MESSAGE_LIMIT = 1000

  module NullDriver
    def self.log(message, room)
      @messages ||= []
      message['room'] = room
      @messages.push message
      @messages = @messages[-MEMORY_MESSAGE_LIMIT..-1] if @messages.size > MEMORY_MESSAGE_LIMIT
    end

    def self.lastlog(number, room)
      @messages ||= []
      @messages.select { |m| m['room'] == room }[0..number]
    end

    def self.find_user(name)
    end

    def self.set_rooms(name, rooms)
    end
  end
end

