require 'minitest/autorun'
require 'webmock/minitest'

require '../lib/scalarm/service_core/information_service'
require '../lib/scalarm/service_core/logger'

class InformationServiceTest < Minitest::Test

  def setup
    @host = 'system.scalarm.com'

    @is = Scalarm::ServiceCore::InformationService.new("#{@host}:11300", 'scalarm', 'scalarm')
    @is2 = Scalarm::ServiceCore::InformationService.new("#{@host}/information", 'scalarm', 'scalarm')
  end

  def test_get_experiment_manager_host_port
    stub_request(:any, "https://#{@host}:11300/experiment_managers").to_return(
        body: "[\"system.scalarm.com\"]",
        headers: {'Content-Type' => 'application/json'}
    )

    em_list = @is.get_list_of('experiment_managers')
    assert (not em_list.empty?)
  end

  def test_get_experiment_manager_host_path
    stub_request(:any, "https://#{@host}/information/experiment_managers").to_return(
        body: "[\"system.scalarm.com\"]",
        headers: {'Content-Type' => 'application/json'}
    )

    stub_request(:any, "https://#{@host}/information/storage_managers").to_return(
        body: '[]',
        headers: {'Content-Type' => 'application/json'}
    )

    em_list = @is2.get_list_of('experiment_managers')
    assert (not em_list.empty?)

    sm_list = @is2.get_list_of('storage_managers')
    assert (not sm_list.nil?)
    assert_empty sm_list
  end

end