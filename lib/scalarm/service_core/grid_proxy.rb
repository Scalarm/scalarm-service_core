require 'grid-proxy/proxy'
require 'grid-proxy/exceptions'

require_relative 'logger'
require_relative 'configuration'

##
# Scalarm extensions for GridProxy
#
# Based on original grid-proxy: https://gitlab.dev.cyfronet.pl/commons/grid-proxy
module Scalarm::ServiceCore::GridProxy
  class Proxy < GP::Proxy
    def verify_for_plgrid!
      crl = Scalarm::ServiceCore::Configuration.proxy_crl
      ca = Scalarm::ServiceCore::Configuration.proxy_ca
      Scalarm::ServiceCore::Logger.warn 'Proxy CRL not loaded' if crl.nil?
      raise 'Proxy CA not loaded' if ca.nil?
      verify!(ca, crl)
    end

    def valid_for_plgrid?
      begin
        verify_for_plgrid!
        true
      rescue GP::ProxyValidationError => e
        false
      end
    end

    def dn
      proxycert.issuer.to_s
    end
  end
end
