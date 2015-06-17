require 'openssl'
require 'net/https'

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

    def initialize(service_url, username, password, development=false)
      @service_url = service_url
      @username = username
      @password = password
      @development = development
    end

    def register_service(service, host, port)
      Logger.info("InformationService: Registering #{service} at address '#{host}:#{port}'")
      code, body = send_request(service, {address: "#{host}:#{port}"})

      if code == '200'
        response = JSON.parse(body)
        puts response.inspect
        if response['status'] == 'ok'
          return nil, response['msg']
        else
          return 'error', response['msg']
        end
      else
        return 'error', code
      end
    end

    def deregister_service(service, host, port)
      code, body = send_request(service, {address: "#{host}:#{port}"}, method: 'DELETE')

      if code == '200'
        response = JSON.parse(body)
        if response['status'] == 'ok'
          return nil, response['msg']
        else
          return 'error', response['msg']
        end
      else
        return 'error', code
      end
    end

    def get_list_of(service)
      code, body = send_request(service)

      if code == '200'
        JSON.parse(body)
      else
        []
      end
    end

    def send_request(request, data = nil, opts = {})
      @host, @port = @service_url.split(':')
      @port, @prefix = @port.split('/')
      @prefix = @prefix.nil? ? '/' : "/#{@prefix}/"

      Logger.info("InformationService: sending #{request} request to the Information Service at '#{@host}:#{@port}'")

      req = if data.nil?
              Net::HTTP::Get.new(@prefix + request)
            else
              if opts.include?(:method) and opts[:method] == 'DELETE'
                Net::HTTP::Delete.new(@prefix + request)
              else
                Net::HTTP::Post.new(@prefix + request)
              end
            end

      req.basic_auth(@username, @password)
      req.set_form_data(data) unless data.nil?

      if @development
        ssl_options = {}
      else
        ssl_options = { use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE }
      end

      begin
        response = Net::HTTP.start(@host, @port, ssl_options) { |http| http.request(req) }
        #puts "#{Time.now} --- response from Information Service is #{response.code} #{response.body}"
        return response.code, response.body
      rescue Exception => e
        Logger.error("Exception occurred on request to Information Service: #{e.to_s}")
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
