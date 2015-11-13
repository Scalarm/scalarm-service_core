require 'openssl'
require 'net/https'

module Scalarm
  module ServiceCore
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


        scheme = @development ? 'http' : 'https'

        @uri = URI("#{scheme}://#{username}:#{password}@#{service_url}")
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
          req.set_form_data(data) unless data.nil?
        end

        if @uri.scheme == 'http'
          ssl_options = {}
        else
          ssl_options = { use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE }
        end

        begin
          response = Net::HTTP.start(@uri.host, @uri.port, ssl_options) { |http| http.request(req) }
          #puts "#{Time.now} --- response from Information Service is #{response.code} #{response.body}"
          return response.code, response.body
        rescue => e
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
end
