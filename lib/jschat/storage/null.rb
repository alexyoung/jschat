module JsChat::Storage
  MEMORY_MESSAGE_LIMIT = 100

  module NullDriver
    def self.log(message, room)
      @messages ||= []
      message['room'] = room
      @messages.push message
      @messages = @messages[-MEMORY_MESSAGE_LIMIT..-1] if @messages.size > MEMORY_MESSAGE_LIMIT
    end

    def self.lastlog(number, room)
      @messages ||= []
      @messages.select { |m| m['room'] == room }.reverse[0..number].reverse
    end

    def self.search(query, room, limit)
      @messages ||= []
      @messages.select do |m|
        m['message'] and m['message']['message'].match(query) and m['room'] == room
      end.reverse[0..limit].reverse
    end

    def self.find_user(options)
    end

    def self.save_user(user)
    end

    def self.delete_user(user)
    end
  end
end

