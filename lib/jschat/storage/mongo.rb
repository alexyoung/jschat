begin
  require 'mongo'
rescue LoadError
end

module JsChat::Storage
  module MongoDriver
    def self.connect!
      @db = Mongo::Connection.new(ServerConfig['db_host'], ServerConfig['db_port']).db(ServerConfig['db_name'])
    end

    def self.log(message, room)
      message['room'] = room
      @db['events'].insert(message)
    end

    def self.lastlog(number, room)
      @db['events'].find({ :room => room }, { :limit => number, :sort => ['time', Mongo::ASCENDING] }).to_a
    end

    # TODO: use twitter oauth for the key
    def self.find_user(options)
      @db['users'].find_one(options)
    end

    def self.save_user(user)
      @db['users'].save user
    end

    def self.set_rooms(name, rooms)
      user = find_user({ 'name' => name })
      user ||= { 'name' => name }
      user['rooms'] = rooms
      save_user user
    end

    def self.available?
      return unless Object.const_defined?(:Mongo)
      connect!
    rescue
      puts 'Failed to connect to mongo'
      false
    end
  end
end
