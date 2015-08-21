require 'scalarm/database/core/mongo_active_record'
require 'scalarm/database/logger'
require 'scalarm/service_core/logger'

class MongoActiveRecordInitializer
  DEFAULT_DB_SECRET_KEY = 'QjqjFK}7|Xw8DDMUP-O$yp'

  ##
  # Initialize connection with MongoDB
  # * config - Hash with keys:
  # ** db_name
  # ** db_secret_key
  # ** (optional) auth_username
  # ** (optional) auth_password
  # * options - Hash with additional options for initializer
  # ** ignore_connection_failure - set true if want to ignore connection errors
  #     attention: with this option, database may be not initialzed after this run
  def self.start(config, options=nil)
    options ||= {}
    ignore_connection_failure = options[:ignore_connection_failure]

    if config.nil?
      puts('mongo_active_record', 'No database configuration, using defaults')
      config = {}

      config['db_name'] = 'scalarm_db'
      config['db_secret_key'] = 'QjqjFK}7|Xw8DDMUP-O$yp'
    end

    db_key = Digest::SHA256.hexdigest(config['db_secret_key'] || DEFAULT_DB_SECRET_KEY)
    Scalarm::Database::MongoActiveRecord.set_encryption_key(db_key)

    # by default, try to connect to local mongodb
    # TODO: connect to local mongodb only if list of db_routers is empty
    puts('mongo_active_record', 'Trying to connect to localhost')


    begin
      Scalarm::Database::MongoActiveRecord.connection_init('localhost', config['db_name'],
                                                           username: config['auth_username'],
                                                           password: config['auth_password'])
    rescue Mongo::ConnectionFailure
      puts('mongo_active_record', 'Cannot connect to local mongodb - fetching mongodb adresses from IS')
      information_service = InformationService.instance
      storage_manager_list = information_service.get_list_of('db_routers')

      if storage_manager_list.blank?
        puts('init', 'Error: db_routers list from IS is empty - there is no database to connect')
        raise 'db_routers list from IS is empty'
      else
        puts('init', "Fetched db_routers list: #{storage_manager_list}")
        db_router_url = storage_manager_list.sample
        puts('mongo_active_record', "Connecting to '#{db_router_url}'")
        Scalarm::Database::MongoActiveRecord.connection_init(db_router_url, config['db_name'],
                                                             username: config['auth_username'],
                                                             password: config['auth_password'])
      end

    end

    configure_mongo_session_if_available(config['db_name'])
  end

  def self.configure_mongo_session_if_available(db_name)
    if Scalarm::Database::MongoActiveRecord.connected? and defined? MongoStore::Session
      puts('mongo_active_record', "Setting #{db_name} as a session storage")
      MongoStore::Session.database = Scalarm::Database::MongoActiveRecord.get_database(db_name)
    end
  end
end