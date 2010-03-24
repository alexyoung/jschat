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
      message['time_index'] = Time.now.to_i
      message['room'] = room
      @db['events'].insert(message)
    end

    def self.lastlog(number, room)
      @db['events'].find({ :room => room }, { :limit => number, :sort => ['time_index', Mongo::ASCENDING] }).to_a
    end

    # TODO: use twitter oauth for the key
    def self.find_user(name)
      @db['users'].find_one('name' => name)
    end

    def self.set_rooms(name, rooms)
      user = find_user name
      user ||= { 'name' => name }
      user['rooms'] = rooms
      @db['users'].save user
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
