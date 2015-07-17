##
# Each authentication method must set:
# [@current_user or @sm_user] to scalarm user or simulation manager temp pass respectively
# [@session_auth] to true if this is session-based authentication
#
# Stateful authentication methods should also set:
# [session[:user]] to user id as string,
# [session[:uuid]] to unique session id (for separate browser/clients)
require 'active_support/concern'
require 'action_controller/metal/mime_responds'
require 'abstract_controller/helpers'

require 'scalarm/database/core'

require 'scalarm/service_core/parameter_validation'

module Scalarm
  module ServiceCore
    module StatusController
      extend ActiveSupport::Concern
      include ActionController::MimeResponds

=begin
  @api {get} /status Service status
  @apiName status#index
  @apiGroup Status
  @apiDescription Returns information about service status

  @apiParam {String[]="database"} [tests] Additional tests to perform

  @apiSuccess {String="ok","error"} status ok if everything is OK
  @apiSuccess {String} [message] Additional status message, eg. if some tests failed
=end
      def status
        params[:tests] = Scalarm::ServiceCore::Utils.parse_json_if_string(params[:tests]) || []
        params[:tests] = params[:tests].collect &:to_s

        validate(
            tests: [
                :optional, :array,
                Proc.new do |name, value|
                  unless value.all? {|elem| Scalarm::ServiceCore::Utils.get_validation_regexp(:default).match(elem)}
                    raise Scalarm::ServiceCore::ParameterValidation::ValidationError.new(name, value, 'Not all test names are safe string')
                  end
                end
            ]
        )

        tests = params[:tests]
        status = 'ok'
        message = ''

        unless tests.nil?
          failed_tests = tests.select do |t_name|
            test_method_name = "status_test_#{t_name}"
            not respond_to? test_method_name or not send(test_method_name)
          end

          unless failed_tests.empty?
            status = 'failed'
            message = "Failed tests: #{failed_tests.map {|tn| ERB::Util.h(tn)}.join(', ')}"
          end
        end

        http_status = (status == 'ok' ? :ok : :internal_server_error)

        respond_to do |format|
          format.html do
            render plain: message, status: http_status
          end
          format.json do
            render json: {status: status, message: message}, status: http_status
          end
        end
      end

      # --- Status tests ---

      def status_test_database
        Scalarm::Database::MongoActiveRecord.available?
      end

    end
  end
end
