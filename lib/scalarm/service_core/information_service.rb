require 'openssl'
require 'net/https'

require_relative 'logger'

module Scalarm::ServiceCore
  class InformationService

    ## TODO: implement, when general secrets/config access will be done
    # def self.create_from_config
    #   service_url = Rails.application.secrets.information_service_url
    #   username = Rails.application.secrets.information_service_user
    #   password = Rails.application.secrets.information_service_pass
    #   development = !!Rails.application.secrets.information_service_development
    #
    #   self.new(service_url, username, passord, development)
    # end

    # url can be: <host>:<port>/<path>
    # if development == false then scheme = https:// and http otherwise
    def initialize(service_url, username, password, development=false)
      @service_url = service_url
      @username = username
      @password = password
      @development = development


      scheme = @development ? 'http' : 'https'

      @uri = URI("#{scheme}://#{username}:#{password}@#{service_url}")
    end

    def register_service(service, url)
      Logger.info("[InformationService]: registering '#{service}' at '#{url}'")
      code, body = send_request(service, {address: url})

      case code.to_i
        when 200..201
          Logger.info("[InformationService]: service '#{service}' registered at '#{url}'")
          return nil, body
        when 403
          Logger.warn("[InformationService]: service '#{service}' at '#{url}' is already registered")
          return 'error', '403'
        when 401
          Logger.error("[InformationService]: authentication error")
          return 'error', '401'
        else
          Logger.error("[InformationService]: unsupported code")
          return 'error', code
      end
    end

    def deregister_service(service, url)
      code, _ = send_request(service + '/' + url, {}, method: 'DELETE')

      case code.to_i
        when 200
          return nil, nil
        else
          Logger.error("[InformationService]: unsupported code")
          return 'error', code
      end

    end

    def get_list_of(service)
      code, body = send_request(service)

      return case code.to_i
        when 200
          JSON.parse(body)
        when 404
          Logger.error("[InformationService]: resource '#{service}' not found")
          []
        when 504
          Logger.error("[InformationService]: got 504 when connecting to '#{@uri}'")
          nil
        else
          Logger.error("[InformationService]: unsupported code '#{@uri}'")
          nil
      end
    end

    def send_request(request, data = nil, opts = {})
      Logger.info("[InformationService]: sending #{request} request at '#{@uri}")
      resource = @uri.path + '/' + request

      req = if data.nil?
              Net::HTTP::Get.new(resource)
            else
              if opts.include?(:method) and opts[:method] == 'DELETE'
                Net::HTTP::Delete.new(resource)
              else
                Net::HTTP::Post.new(resource)
              end
            end

      if not req.is_a?(Net::HTTP::Get)
        req.basic_auth(@username, @password)
        req.set_form_data(data) unless data.empty?
      end

      if @uri.scheme == 'http'
        ssl_options = {}
      else
        ssl_options = { use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE }
      end

      begin
        response = Net::HTTP.start(@uri.host, @uri.port, ssl_options) { |http| http.request(req) }
        #puts "#{Time.now} --- response from Information Service is #{response.code} #{response.body}"
        # registering services case
        if response.code == '201' and response['Location']
          response.body = response['Location']
        end

        return response.code, response.body
      rescue Exception => e
        Logger.error("[InformationService] Exception occurred: #{e.to_s}")
        Logger.error(e.backtrace.join("\n\t"))

        raise
      end

      return nil, nil
    end

    def sample_public_url(service)
      (get_list_of(service) or []).sample
    end

  end

end
