begin
  require 'mongo'
rescue LoadError
end

module JsChat::Storage
  module MongoDriver
    def self.connect!
      @db = Mongo::Connection.new(ServerConfig['db_host'], ServerConfig['db_port'], :slave_ok => true).db(ServerConfig['db_name'])
      if ServerConfig['db_username'] and ServerConfig['db_password']
        if @db.authenticate(ServerConfig['db_username'], ServerConfig['db_password'])
          true
        else
          raise 'Bad Mongo username or password'
        end
      else
        true
      end
    end

    def self.log(message, room)
      message['room'] = room
      @db['events'].insert(message)
    end

    def self.lastlog(number, room)
      @db['events'].find({ :room => room }, { :limit => number, :sort => ['time', Mongo::DESCENDING] }).to_a.reverse
    end

    def self.search(query, room, limit)
      query = /\b#{query}\b/i
      @db['events'].find({ 'message.message' => query, 'room' => room },
        { :limit => limit, :sort => ['time', Mongo::DESCENDING] }
      ).to_a.reverse
    end

    # TODO: use twitter oauth for the key
    def self.find_user(options)
      @db['users'].find_one(options)
    end

    def self.save_user(user)
      @db['users'].save user
    end

    def self.delete_user(user)
      @db['users'].remove user
    end

    def self.available?
      return unless Object.const_defined?(:Mongo)
      connect!
    rescue
      p $!
      puts 'Failed to connect to mongo'
      false
    end
  end
end
