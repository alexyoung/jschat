module JsChat::Storage
  module NullDriver
    def self.log(message)
      @messages ||= []
      @messages.push message
      @messages = @messages[-100..-1] if @messages.size > 100
    end

    def self.lastlog(number)
      @messages ||= []
      @messages[0..number]
    end

    def self.find_user(name)
    end

    def self.set_rooms(name, rooms)
    end
  end
end

