module Scalarm
  module ServiceCore
    module TestUtils
      module DbHelper
        DATABASE_NAME = 'scalarm_db_test'

        require 'scalarm/database/core/mongo_active_record'

        def rails_mock
          if not defined? Rails or Rails.methods.grep(/application/).empty?
            secrets = mock('object')
            secrets.stubs(:database).returns({})
            application = mock('object')
            application.stubs(:secrets).returns(secrets)

            rails_module = Class.new(Object)
            if not defined? Rails
              DbHelper.const_set("Rails", rails_module)
            end

            Rails.stubs(:application).returns(application)
          end
        end

        def setup(database_name=DATABASE_NAME)
          rails_mock
          db_config ||= Rails.application.secrets.database
          default_mongodb_host = db_config['host'] || 'localhost'
          default_mongodb_db_name = db_config['db_name'] || database_name

          Scalarm::Database::MongoActiveRecord.set_encryption_key(db_config['db_secret_key'] || 'db_key')

          unless Scalarm::Database::MongoActiveRecord.connected?
            begin
              connection_init = Scalarm::Database::MongoActiveRecord.connection_init(default_mongodb_host, default_mongodb_db_name)
              ## If mongo_session is available - configure it with test database
              if defined? MongoStore::Session
                MongoStore::Session.database = Scalarm::Database::MongoActiveRecord.get_database(DATABASE_NAME)
              end
            rescue Mongo::ConnectionFailure => e
              skip "Connection to database failed: #{e.to_s}"
            end
            skip 'Connection to database failed' unless connection_init
            ## Old behavior - error on database connection failure
            #raise StandardError.new('Connection to database failed') unless connection_init
            puts "Connected with database '#{database_name}' on host '#{default_mongodb_host}'"
          end
        end

        # Drop all collections after each test case.
        def teardown(database_name=DATABASE_NAME)
          rails_mock
          db_config ||= Rails.application.secrets.database
          default_mongodb_db_name = db_config['db_name'] || database_name

          db = Scalarm::Database::MongoActiveRecord.get_database(default_mongodb_db_name)
          if db.nil?
            puts 'Disconnection from database failed'
          else
            db.drop
          end
        end

      end
    end
  end
end