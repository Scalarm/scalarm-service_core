require 'minitest/autorun'
require 'webmock/minitest'

require '../lib/scalarm/service_core/information_service'

class InformationServiceTest < Minitest::Test

  def setup
    @host = 'system.scalarm.com'

    @is = Scalarm::ServiceCore::InformationService.new("#{@host}:11300", 'scalarm', 'scalarm')
    @is2 = Scalarm::ServiceCore::InformationService.new("#{@host}/information", 'scalarm', 'scalarm')
  end

  def test_get_experiment_manager_host_port
    stub_request(:any, "https://#{@host}:11300/experiment_managers").to_return(
      body: "[\"darek.isi.edu\"]",
      headers: { 'Content-Type' => 'application/json' }
    )

    em_list = @is.get_list_of('experiment_managers')
    assert (not em_list.empty?)
  end

  def test_get_experiment_manager_host_path
    stub_request(:get, "https://#{@host}/information/experiment_managers").to_return(
      body: "[\"darek.isi.edu\"]",
      headers: { 'Content-Type' => 'application/json' }
    )

    stub_request(:get, "https://#{@host}/information/storage_managers").to_return(
      body: '[]',
      headers: { 'Content-Type' => 'application/json' }
    )

    em_list = @is2.get_list_of('experiment_managers')
    assert (not em_list.empty?)

    sm_list = @is2.get_list_of('storage_managers')
    assert (not sm_list.nil?)
    assert_empty sm_list
  end

  def test_get_incorrect_service
    stub_request(:get, "https://#{@host}/information/experimental_resources").to_return(status: 404)

    em_list = @is2.get_list_of('experimental_resources')

    assert_empty em_list
  end

  def test_get_with_bad_gateway
    stub_request(:get, "https://#{@host}/information/db_routers").to_return(status: 504)

    db_list = @is2.get_list_of('db_routers')
    assert_nil db_list
  end

  def test_registering_new_service_instance
    stub_request(:post, "https://scalarm:scalarm@#{@host}/information/experiment_managers").
      with(body: { address: @host }, headers: { 'Content-Type'=>'application/x-www-form-urlencoded' } ).
      to_return(status: 201, headers: {'Location' => "https://#{@host}/information/experiment_managers/#{@host}"})

    err, location = @is2.register_service('experiment_managers', @host)

    assert_nil err
    assert location == "https://#{@host}/information/experiment_managers/#{@host}"
  end

  def test_registering_existing_service_instance
    stub_request(:post, "https://scalarm:scalarm@#{@host}/information/experiment_managers").
      with(body: { address: @host }, headers: { 'Content-Type'=>'application/x-www-form-urlencoded' } ).
      to_return(status: 403)

    err, code = @is2.register_service('experiment_managers', @host)

    assert err == 'error'
    assert code == '403'
  end

  def test_registering_service_without_authorization
    stub_request(:post, "https://#{@host}/information/experiment_managers").
      with(body: { address: @host }, headers: { 'Content-Type'=>'application/x-www-form-urlencoded' } ).
      to_return(status: 401)

    is = Scalarm::ServiceCore::InformationService.new("#{@host}/information", nil, nil)

    err, code = is.register_service('experiment_managers', @host)

    assert err == 'error'
    assert code == '401'
  end

  def test_deregistering_service_without_authorization
    stub_request(:delete, "https://#{@host}/information/experiment_managers/#{@host}").to_return(status: 401)

    is = Scalarm::ServiceCore::InformationService.new("#{@host}/information", nil, nil)

    err, code = is.deregister_service('experiment_managers', @host)

    assert err == 'error'
    assert code == '401'
  end

  def test_deregistering_service
    stub_request(:delete, "https://scalarm:scalarm@#{@host}/information/experiment_managers/#{@host}").
        to_return(status: 200)

    err, _ = @is2.deregister_service('experiment_managers', @host)

    assert_nil err
  end

end
