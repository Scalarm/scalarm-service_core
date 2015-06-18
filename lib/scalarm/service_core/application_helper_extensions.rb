module Scalarm
  module ServiceCore
    module ApplicationHelperExtensions

      def current_user
        @current_user
      end

      def sm_user
        @sm_user
      end

      def user_session
        @user_session
      end

    end
  end
end