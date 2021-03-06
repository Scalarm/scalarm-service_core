require 'securerandom'

require 'scalarm/database/model/user_session'

module Scalarm
  module ServiceCore
    class UserSession < Scalarm::Database::Model::UserSession

      def valid?
        if Time.now.to_i - self.last_update.to_i > Rails.configuration.session_threshold
          false
        else
          true
        end
      end

      def self.create_and_update_session(user_id, uuid)
        session_id = BSON::ObjectId(user_id.to_s)
        if uuid.nil?
          uuid = session[:uuid] = SecureRandom.uuid
        end

        session = (UserSession.where(session_id: session_id, uuid: uuid).first or
            UserSession.new(session_id: session_id, uuid: uuid))
        session.last_update = Time.now
        session.save

        session
      end


    end
  end
end
