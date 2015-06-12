module Scalarm
  module ServiceCore

    ##
    # A module to extend controller for CORS support
    module CorsSupport
      extend ActiveSupport::Concern

      def check_request_origin
        unless request_origin_allowed?(request.env['HTTP_ORIGIN'])
          raise "Request origin #{request.env['HTTP_ORIGIN']} not allowed"
        end
      end

      def add_cors_header
        headers['Access-Control-Allow-Origin'] = request.env['HTTP_ORIGIN']
        headers['Access-Control-Allow-Credentials'] = 'true'
        headers['Access-Control-Allow-Methods'] = 'POST, GET, PUT, DELETE, OPTIONS'
        headers['Access-Control-Allow-Headers'] = 'Origin, Content-Type, Accept, Authorization, Token'
        headers['Access-Control-Max-Age'] = '1728000'
      end

      def cors_preflight_check
        if request.method == 'OPTIONS'
          headers['Access-Control-Allow-Origin'] = request.env['HTTP_ORIGIN']
          headers['Access-Control-Allow-Credentials'] = 'true'
          headers['Access-Control-Allow-Methods'] = 'POST, GET, PUT, DELETE, OPTIONS'
          headers['Access-Control-Allow-Headers'] = 'X-Requested-With, X-Prototype-Version, Token'
          headers['Access-Control-Max-Age'] = '1728000'

          render :text => '', :content_type => 'text/plain'
        end
      end

      def request_origin_allowed?(origin)
        Logger.info("origin: #{origin}")
        Logger.info("allow all: #{Scalarm::ServiceCore::Configuration.cors_allow_all_origins}")
        Logger.info("allowed: #{Scalarm::ServiceCore::Configuration.cors_allowed_origins} ")

        Scalarm::ServiceCore::Configuration.cors_allow_all_origins or
            Scalarm::ServiceCore::Configuration.cors_allowed_origins.include?(origin)
      end
    end
  end
end