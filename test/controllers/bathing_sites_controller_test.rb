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

  test "weather returns timestamped weather payload" do
    payload = {
      source: "stormglass",
      fetched_at: "2026-05-03T09:00:00Z",
      location: { latitude: 55.75, longitude: -1.99 },
      metrics: {
        air_temperature_c: {
          status: "available",
          value: 12.3,
          observed_at: "2026-05-03T09:00:00Z",
          unavailable_reason: nil
        },
        wind_speed_m_s: {
          status: "available",
          value: 5.4,
          observed_at: "2026-05-03T09:00:00Z",
          unavailable_reason: nil
        },
        water_temperature_c: {
          status: "available",
          value: 11.2,
          observed_at: "2026-05-03T09:00:00Z",
          unavailable_reason: nil
        },
        wave_height_m: {
          status: "available",
          value: 0.9,
          observed_at: "2026-05-03T09:00:00Z",
          unavailable_reason: nil
        },
        next_high_tide_at: {
          status: "available",
          value: "2026-05-03T10:20:00Z",
          observed_at: "2026-05-03T10:20:00Z",
          unavailable_reason: nil
        },
        next_low_tide_at: {
          status: "available",
          value: "2026-05-03T16:40:00Z",
          observed_at: "2026-05-03T16:40:00Z",
          unavailable_reason: nil
        }
      }
    }

    client_class = Class.new do
      def initialize(payload)
        @payload = payload
      end

      def current_conditions(latitude:, longitude:)
        @payload.merge(location: { latitude: latitude, longitude: longitude })
      end
    end

    stub_client = client_class.new(payload)

    singleton = Stormglass::MarineClient.singleton_class
    singleton.alias_method :__original_new_for_weather_test, :new
    singleton.define_method(:new) { stub_client }

    begin
      get weather_bathing_sites_url(lat: "55.75", lng: "-1.99")
    ensure
      singleton.alias_method :new, :__original_new_for_weather_test
      singleton.remove_method :__original_new_for_weather_test
    end

    assert_response :success
    parsed = JSON.parse(response.body)
    assert_equal "stormglass", parsed["source"]
    assert_equal "available", parsed.dig("metrics", "air_temperature_c", "status")
    assert_equal "available", parsed.dig("metrics", "wave_height_m", "status")
  end

  test "wiki rejects blank site_name" do
    get wiki_bathing_sites_url(site_name: "")

    assert_response :unprocessable_entity
    parsed = JSON.parse(response.body)
    assert_equal "site_name is required", parsed["errors"].first
  end

  test "wiki returns description and image from Wikipedia client" do
    payload = {
      description: "Spittal is a village in Northumberland near Berwick-upon-Tweed.",
      image_url: "https://upload.wikimedia.org/wikipedia/commons/thumb/spittal.jpg/800px-spittal.jpg",
      wikipedia_url: "https://en.wikipedia.org/wiki/Spittal,_Northumberland",
      unavailable_reason: nil
    }

    stub_client = Class.new do
      def initialize(payload) = @payload = payload
      def fetch(site_name:) = @payload
    end.new(payload)

    singleton = Wikipedia::LocationClient.singleton_class
    singleton.alias_method :__original_new_for_wiki_test, :new
    singleton.define_method(:new) { stub_client }

    begin
      get wiki_bathing_sites_url(site_name: "Spittal")
    ensure
      singleton.alias_method :new, :__original_new_for_wiki_test
      singleton.remove_method :__original_new_for_wiki_test
    end

    assert_response :success
    parsed = JSON.parse(response.body)
    assert_equal "Spittal is a village in Northumberland near Berwick-upon-Tweed.", parsed["description"]
    assert_not_nil parsed["image_url"]
    assert_not_nil parsed["wikipedia_url"]
    assert_nil parsed["unavailable_reason"]
  end
end
