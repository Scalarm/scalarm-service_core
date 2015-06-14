require 'minitest/autorun'
require 'mocha/mini_test'

require 'scalarm/service_core/configuration'

class LoggerTest < MiniTest::Test

  ##
  # Check default CORS settings
  def test_default_cors
    refute_nil Scalarm::ServiceCore::Configuration.cors_allow_all_origins
    refute_nil Scalarm::ServiceCore::Configuration.cors_allow_credentials
    refute_nil Scalarm::ServiceCore::Configuration.cors_allowed_origins
  end

end