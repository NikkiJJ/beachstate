require "test_helper"

class BathingSitesControllerTest < ActionDispatch::IntegrationTest
  test "index returns Environment Agency bathing sites" do
    sites = [
      {
        id: "ukc2102-03600",
        site_name: "Spittal",
        region: "Northumberland",
        description: "Water quality can be impacted by heavy rainfall.",
        latitude: 55.756856,
        longitude: -1.988831,
        location_label: "Spittal, Northumberland",
        quality_classification: "Good",
        quality_classification_uri: "http://environment.data.gov.uk/def/bwq-cc-2015/2",
        official_uri: "http://environment.data.gov.uk/id/bathing-water/ukc2102-03600",
        eubwid_notation: "ukc2102-03600",
        heavy_rain_affected: true,
        created_at: nil,
        updated_at: nil
      }
    ]

    client_class = Class.new do
      attr_reader :received_query

      def initialize(sites)
        @sites = sites
      end

      def list_sites(query:)
        @received_query = query
        @sites
      end
    end

    stub_client = client_class.new(sites)

    singleton = EnvironmentAgency::BathingWaterClient.singleton_class
    singleton.alias_method :__original_new_for_test, :new
    singleton.define_method(:new) { stub_client }

    begin
      get bathing_sites_url
    ensure
      singleton.alias_method :new, :__original_new_for_test
      singleton.remove_method :__original_new_for_test
    end

    assert_response :success

    parsed = JSON.parse(response.body)
    assert_equal "Spittal", parsed.first["site_name"]
    assert_equal "Good", parsed.first["quality_classification"]
    assert_nil stub_client.received_query
  end
end
