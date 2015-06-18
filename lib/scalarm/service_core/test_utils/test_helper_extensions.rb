module Scalarm
  module ServiceCore
    module TestUtils
      module TestHelperExtensions
        require 'minitest/autorun'
        require 'test_helper'
        require 'mocha/test_unit'

        require 'scalarm/service_core/scalarm_user'
        require 'scalarm/service_core/user_session'
        require 'scalarm/service_core/scalarm_authentication'

        ##
        # A @user variable will contain session's ScalarmUser
        def stub_authentication
          # bypass authentication
          ApplicationController.any_instance.stubs(:authenticate)

          @user = Scalarm::ServiceCore::ScalarmUser.new(login: 'login')
          @sm_user = nil
          @user_session = nil

          ApplicationController.any_instance.stubs(:current_user).returns(@user)
          ApplicationController.any_instance.stubs(:sm_user).returns(@sm_user)
          ApplicationController.any_instance.stubs(:user_session).returns(@user_session)
        end

      end
    end
  end
end

