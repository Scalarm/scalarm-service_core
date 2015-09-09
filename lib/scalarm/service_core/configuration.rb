require_relative 'logger'

module Scalarm::ServiceCore

  class Configuration
    require 'active_support/core_ext/class/attribute_accessors'

    DEFAULT_PROXY_CA_PATH = "#{File.dirname(__FILE__)}/../../proxy/plgrid_ca.pem"
    DEFAULT_PROXY_CRL_PATH = "#{File.dirname(__FILE__)}/../../proxy/plgrid_crl.pem"

    # For proxy_crl read/write synchronization
    @@crl_mutex = Mutex.new

    ##
    # Load Proxy's CA from custom location.
    # By default, bundled CA is used.
    def self.load_proxy_ca(path)
      @@proxy_ca = File.read(path)
    end

    ##
    # Load Proxy's CRL from custom location.
    # This method is synchonized with proxy_crl read
    # By default, bundled CRL is used.
    def self.load_proxy_crl(path)
      @@crl_mutex.synchronize do
        @@proxy_crl = File.read(path)
      end
    end

    # Get proxy_crl
    # Synchronized with proxy_crl load and auto_update
    def self.proxy_crl
      @@crl_mutex.synchronize do
        @@proxy_crl
      end
    end

    cattr_reader :proxy_ca

    load_proxy_ca(DEFAULT_PROXY_CA_PATH)
    load_proxy_crl(DEFAULT_PROXY_CRL_PATH)

    cattr_accessor :anonymous_login
    cattr_accessor :anonymous_password

    # CORS: allow all origins by default
    cattr_accessor :cors_allow_all_origins
    self.cors_allow_all_origins = true

    # CORS: list of allowed origins of allow_all_origins is set to false
    cattr_accessor :cors_allowed_origins
    self.cors_allowed_origins = []

    # CORS: Access-Control-Allow-Credentials setting in CORS responses
    cattr_accessor :cors_allow_credentials
    self.cors_allow_credentials = true

    ##
    # Starts automatic CRL file content update from given path using separate thread
    #
    # It will change proxy_crl attribute every interval seconds
    # with content from path file.
    # On fail reading (every StandardError) the file it will leave proxy_crl untouched
    # writing the error to Logger.
    # On other error it will exit the thread so be careful!
    # Function will return started thread.
    def self.start_crl_auto_update(path, interval = 4.hours)
      Thread.start do
        begin
          loop do
            new_content = nil
            crl_modify_date = nil
            begin
              new_content = File.read(path)
              crl_modify_date = File.mtime(path)
            rescue => error
              Logger.error("Error reading CRL file (#{path}): #{error}\n#{error.backtrace.join("\n")}")
            end

            if new_content.nil?
              Logger.warn('CRL content to update is nil, so it will be not updated')
            else
              Logger.info("Updating CRL with content from file #{path}, modified #{crl_modify_date}")
              @@crl_mutex.synchronize do
                @@proxy_crl = new_content
              end
            end

            sleep(interval)
          end
        rescue Exception => e
          Logger.error("Fatal error occured in auto update CRL thread: #{e}. Auto update will be terminated")
          raise
        end
      end
    end

  end

end