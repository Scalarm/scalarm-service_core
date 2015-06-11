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

require 'scalarm/database/model/simulation_manager_temp_password'

require_relative 'grid_proxy'

require_relative 'scalarm_user'
require_relative 'user_session'

module Scalarm::ServiceCore
  module ScalarmAuthentication
    extend ActiveSupport::Concern
    include ActionController::MimeResponds

    PROXY_HEADER = 'X-Proxy-Cert'
    TOKEN_HEADER = 'X-Scalarm-Token'

    RAILS_PROXY_HEADER = 'HTTP_' + PROXY_HEADER.upcase.gsub('-', '_')
    RAILS_TOKEN_HEADER = 'HTTP_' + TOKEN_HEADER.upcase.gsub('-', '_')

    def initialize
      super
      @proxy_s = nil
    end

    # the main authentication function + session management
    def authenticate
      Logger.debug("[authentication] starting")
      @current_user = nil; @sm_user = nil; @session_auth = false; @user_session = nil

      case true
        when !!(token = get_token(request))
          authenticate_with_token(token)

        when (not session[:user].blank?)
          authenticate_with_session

        when (use_proxy_auth? and proxy_provided?)
          authenticate_with_proxy

        when password_provided?
          authenticate_with_password

        when certificate_provided?
          authenticate_with_certificate
      end

      if @current_user.nil? and @sm_user.nil?
        authentication_failed
      elsif @sm_user.nil? and not session[:user].nil?
        @user_session = UserSession.
            create_and_update_session(session[:user], session[:uuid])
      else
        Logger.debug("[authentication] one-time authentication (without session saving)")
      end

      Logger.debug("[authentication] user_id: #{@current_user.id}") if @current_user
    end

    ##
    # A method to invoke when authentication fails.
    # This is basic implementation - it should be overriden in specific service code.
    def authentication_failed
      respond_to do |format|
        format.html do
          flash[:error] = 'You have to login first'

          redirect_to :index
        end
        format.json do
          Logger.debug('[authentication] 401')

          # TODO: there are problems with AJAX 401 annoying authentication prompts
          headers['WWW-Authenticate'] = %(Basic realm="Scalarm")
          render json: {status: 'error', reason: 'Authentication failed'}, status: :unauthorized
        end
      end
    end

    def authenticate_with_session
      Logger.debug("[authentication] using session: user: #{session[:user]}, uuid: #{session[:uuid]}")
      session_id = BSON::ObjectId(session[:user].to_s)

      @user_session = UserSession.where(session_id: session_id, uuid: session[:uuid]).first

      validate_and_use_session
    end

    def certificate_provided?
      request.env.include?('HTTP_SSL_CLIENT_S_DN') and
          request.env['HTTP_SSL_CLIENT_S_DN'] != '(null)' and
          request.env['HTTP_SSL_CLIENT_VERIFY'] == 'SUCCESS'
    end

    def authenticate_with_certificate
      cert_dn = request.env['HTTP_SSL_CLIENT_S_DN']
      Logger.debug("[authentication] using DN: '#{cert_dn}'")

      begin
        session[:user] = ScalarmUser.authenticate_with_certificate(cert_dn).id.to_s
        session[:uuid] = SecureRandom.uuid
        @current_user = ScalarmUser.find_by_id(session[:user].to_s)
      rescue => e
        @current_user = nil
        flash[:error] = e.to_s
      end
    end

    def password_provided?
      request.env.include?('HTTP_AUTHORIZATION') and request.env['HTTP_AUTHORIZATION'].include?('Basic')
    end

    def authenticate_with_password
      authenticate_or_request_with_http_basic do |login, password|
        temp_pass = Scalarm::Database::Model::SimulationManagerTempPassword.find_by_sm_uuid(login.to_s)
        unless temp_pass.nil?
          Logger.debug("[authentication] SM using uuid: '#{login}'")

          @sm_user = temp_pass if ((not temp_pass.nil?) and (temp_pass.password == password))
        else
          Logger.debug("[authentication] using login: '#{login}'")

          @current_user = ScalarmUser.authenticate_with_password(login, password)
          session[:user] = @current_user.id.to_s unless @current_user.nil?
          session[:uuid] = SecureRandom.uuid
        end
      end
    end

    def use_proxy_auth?
      not Configuration.proxy_ca.nil?
    end

    def proxy_provided?
      request.env.include?(RAILS_PROXY_HEADER)
    end

    def authenticate_with_proxy
      proxy_s = Utils::header_newlines_deserialize(request.env[RAILS_PROXY_HEADER])

      proxy = GridProxy::Proxy.new(proxy_s)
      username = proxy.username

      if username.nil?
        Logger.warn("[authentication] #{PROXY_HEADER} header present, but contains invalid data")
        return
      end

      begin
        dn = proxy.dn
        Logger.debug("[authentication] using proxy certificate: '#{dn}'") # TODO: DN

        proxy.verify_for_plgrid!
        # set proxy string in instance variable for further use in PL-Grid
        @proxy_s = proxy_s

        # pass validation check, because it is already done
        @current_user = ScalarmUser.authenticate_with_proxy(proxy, false)

        if @current_user.nil?
          Logger.debug "[authentication] creating new user based on proxy certificate: #{username}"
          @current_user = ScalarmUser.new(login: username, dn: dn)
          @current_user.save
        end

        puts "current: #{@current_user.id}"

          # session saving on proxy authentication was disabled
          # session[:user] = @current_user.id.to_s unless @current_user.nil?
          # session[:uuid] = SecureRandom.uuid
      rescue GridProxy::ProxyValidationError => e
        Logger.warn "[authentication] proxy validation error: #{e}"
      rescue OpenSSL::X509::CertificateError => e
        Logger.warn "[authentication] OpenSSL error when trying to use proxy certificate: #{e}"
      end
    end

    def get_token(request)
      token = (request.params[:token] or request.env[RAILS_TOKEN_HEADER])
    end

    def authenticate_with_token(token)
      @current_user = ScalarmAuthentication.find_user_by_token(token)
      if @current_user
        # token is used one time
        @current_user.destroy_token!(token)
        validate_and_use_session
      else
        Logger.warn("Invalid token provided: #{token}")
      end
    end

    def self.find_user_by_token(token)
      ScalarmUser.find_by_token(token)
    end

    def validate_and_use_session
      if (not @user_session.nil?) and @user_session.valid?
        Logger.debug("[authentication] scalarm user session exists and its valid")
        @current_user = ScalarmUser.find_by_id(@user_session.session_id)
        @session_auth = true unless @current_user.blank?
      else
        flash[:error] = t('session.expired')
        Logger.debug("[authentication] scalarm user session doesnt exist and its invalid")
      end
    end

  end
end