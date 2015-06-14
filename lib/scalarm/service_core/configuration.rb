module Scalarm::ServiceCore

  class Configuration
    require 'active_support/core_ext/class/attribute_accessors'

    DEFAULT_PROXY_CA_PATH = "#{File.dirname(__FILE__)}/../../proxy/plgrid_ca.pem"
    DEFAULT_PROXY_CRL_PATH = "#{File.dirname(__FILE__)}/../../proxy/plgrid_crl.pem"

    ##
    # Load Proxy's CA from custom location.
    # By default, bundled CA is used.
    def self.load_proxy_ca(path)
      @@proxy_ca = File.read(path)
    end

    ##
    # Load Proxy's CRL from custom location.
    # By default, bundled CRL is used.
    def self.load_proxy_crl(path)
      @@proxy_crl = File.read(path)
    end

    load_proxy_ca(DEFAULT_PROXY_CA_PATH)
    load_proxy_crl(DEFAULT_PROXY_CRL_PATH)

    cattr_reader :proxy_ca
    cattr_reader :proxy_crl

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

    # class << self
    #   self.cors_allow_all_origins = true
    # end

  end

end