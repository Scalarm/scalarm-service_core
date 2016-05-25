module Scalarm
  module ServiceCore
    module TestUtils
      module DbHelper
        DATABASE_NAME = 'scalarm_db_test'

        require 'scalarm/database/core/mongo_active_record'

        def setup(database_name=DATABASE_NAME)
          Scalarm::Database::MongoActiveRecord.set_encryption_key('db_key')

          unless Scalarm::Database::MongoActiveRecord.connected?
            begin
              connection_init = Scalarm::Database::MongoActiveRecord.connection_init('localhost', database_name)
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
            puts "Connected with database #{database_name}"
          end
        end

        # Drop all collections after each test case.
        def teardown(database_name=DATABASE_NAME)
          db = Scalarm::Database::MongoActiveRecord.get_database(database_name)
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