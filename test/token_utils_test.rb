require 'minitest/autorun'
require 'active_support/testing/declarative'
require 'mocha/mini_test'
require 'mocha/parameter_matchers'


require 'scalarm/service_core/test_utils/db_helper'

require 'scalarm/service_core/token_utils'
require 'scalarm/service_core/scalarm_authentication'
require 'scalarm/service_core/scalarm_user'
require 'scalarm/service_core/user_session'


class TokenUtilsTest < MiniTest::Test
  extend ActiveSupport::Testing::Declarative
  include Scalarm::ServiceCore::TestUtils::DbHelper

  def setup
    super

    @login = 'test_login'
    @user = Scalarm::ServiceCore::ScalarmUser.new(login: @login)
    @user.save
  end

  def teardown
    super
  end

  def test_token_generation_and_destroy
    # Given
    require 'restclient'

    user_session = Scalarm::ServiceCore::ScalarmUser.new(
       login: "test_user"
    )

    url = 'url'
    payload = 'payload'
    m_token = 'token'

    assert (user_session.tokens == [] or user_session.tokens == nil),
           'User session tokens should be nil or empty array after session creation'

    Scalarm::ServiceCore::ScalarmUser.stubs(:_gen_random_token).returns(m_token)

    Scalarm::ServiceCore::ScalarmUser.stubs(:find_by_token).with(m_token).
        returns(:user_session)

    # Expectations
    user_session.expects(:destroy_token!).with(m_token).once

    # we don't care what are request parameters in this test
    RestClient::Request.expects(:execute).with(any_parameters).once

    # When
    Scalarm::ServiceCore::TokenUtils.post(url, user_session, payload)
  end

end