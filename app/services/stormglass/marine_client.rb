require "json"
require "net/http"
require "uri"

module Stormglass
  class MarineClient
    WEATHER_BASE_URL = "https://api.stormglass.io/v2/weather/point".freeze
    TIDE_BASE_URL = "https://api.stormglass.io/v2/tide/extremes/point".freeze
    READ_TIMEOUT = 15
    CACHE_TTL = 15.minutes

    def initialize(api_key: ENV["STORMGLASS_API_KEY"], weather_base_url: ENV["STORMGLASS_WEATHER_BASE_URL"].presence || WEATHER_BASE_URL,
                   tide_base_url: ENV["STORMGLASS_TIDE_BASE_URL"].presence || TIDE_BASE_URL)
      @api_key = api_key
      @weather_base_url = weather_base_url
      @tide_base_url = tide_base_url
    end

    def current_conditions(latitude:, longitude:)
      fetched_at = Time.current.iso8601

      unless @api_key.present?
        return unavailable_payload(latitude: latitude, longitude: longitude, fetched_at: fetched_at,
                                   reason: "STORMGLASS_API_KEY is not configured")
      end

      cache_key = "stormglass:conditions:#{latitude.round(3)}:#{longitude.round(3)}"
      cached = Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        fetch_live_conditions(latitude: latitude, longitude: longitude)
      end

      cached.merge(fetched_at: fetched_at)
    rescue StandardError => e
      Rails.logger.error("Stormglass::MarineClient failed: #{e.class}: #{e.message}")
      unavailable_payload(latitude: latitude, longitude: longitude, fetched_at: fetched_at,
                          reason: "provider request failed")
    end

    private

    def fetch_live_conditions(latitude:, longitude:)
      weather_payload = get_weather_json(latitude: latitude, longitude: longitude)
      tide_payload = get_tide_json(latitude: latitude, longitude: longitude)

      weather_reading = pick_current_weather_hour(weather_payload)
      observed_at = value_for(weather_reading["time"])
      next_high_tide, next_low_tide = extract_next_tides(tide_payload)

      {
        source: "stormglass",
        location: {
          latitude: latitude,
          longitude: longitude
        },
        metrics: {
          air_temperature_c: metric(extract_source_value(weather_reading["airTemperature"]), observed_at: observed_at,
                                    reason: "airTemperature missing from provider response"),
          wind_speed_m_s: metric(extract_source_value(weather_reading["windSpeed"]), observed_at: observed_at,
                                 reason: "windSpeed missing from provider response"),
          water_temperature_c: metric(extract_source_value(weather_reading["waterTemperature"]), observed_at: observed_at,
                                      reason: "waterTemperature missing from provider response"),
          wave_height_m: metric(extract_source_value(weather_reading["waveHeight"]), observed_at: observed_at,
                                reason: "waveHeight missing from provider response"),
          weather_condition: metric(wmo_description(extract_source_value(weather_reading["weatherCode"])),
                                    observed_at: observed_at, reason: "weatherCode missing from provider response"),
          next_high_tide_at: metric(next_high_tide, observed_at: next_high_tide,
                                    reason: "next high tide missing from provider response"),
          next_low_tide_at: metric(next_low_tide, observed_at: next_low_tide,
                                   reason: "next low tide missing from provider response")
        }
      }
    end

    def unavailable_payload(latitude:, longitude:, fetched_at:, reason:)
      {
        source: "stormglass",
        fetched_at: fetched_at,
        location: {
          latitude: latitude,
          longitude: longitude
        },
        metrics: {
          air_temperature_c: unavailable_metric(reason),
          wind_speed_m_s: unavailable_metric(reason),
          water_temperature_c: unavailable_metric(reason),
          wave_height_m: unavailable_metric(reason),
          weather_condition: unavailable_metric(reason),
          next_high_tide_at: unavailable_metric(reason),
          next_low_tide_at: unavailable_metric(reason)
        }
      }
    end

    def unavailable_metric(reason)
      {
        status: "unavailable",
        value: nil,
        observed_at: nil,
        unavailable_reason: reason
      }
    end

    def metric(value, observed_at:, reason:)
      if value.nil? || (value.respond_to?(:blank?) && value.blank?)
        return {
          status: "unavailable",
          value: nil,
          observed_at: observed_at,
          unavailable_reason: reason
        }
      end

      {
        status: "available",
        value: value,
        observed_at: observed_at,
        unavailable_reason: nil
      }
    end

    def get_weather_json(latitude:, longitude:)
      uri = URI(@weather_base_url)
      uri.query = URI.encode_www_form(
        lat: latitude,
        lng: longitude,
        params: "airTemperature,windSpeed,waterTemperature,waveHeight,weatherCode"
      )

      get_json(uri)
    end

    def get_tide_json(latitude:, longitude:)
      now = Time.current.utc
      uri = URI(@tide_base_url)
      uri.query = URI.encode_www_form(
        lat: latitude,
        lng: longitude,
        start: now.iso8601,
        end: (now + 48.hours).iso8601
      )

      get_json(uri)
    end

    def get_json(uri)
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      request["Authorization"] = @api_key

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: READ_TIMEOUT) do |http|
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise "Unexpected response #{response.code} for #{uri}"
      end

      JSON.parse(response.body)
    end

    def pick_current_weather_hour(payload)
      hours = payload["hours"] || []
      return {} if hours.empty?

      now = Time.current
      current = hours.find do |entry|
        timestamp = parse_timestamp(value_for(entry["time"]))
        timestamp.present? && timestamp >= now
      end

      current || hours.first || {}
    end

    def extract_source_value(value)
      return nil if value.nil?
      return value if value.is_a?(Numeric) || value.is_a?(String)
      return nil unless value.is_a?(Hash)

      preferred_sources = %w[sg noaa dwd meto icon]
      preferred_sources.each do |source|
        return value[source] if value[source].present?
      end

      first = value.values.find { |entry| entry.present? }
      first
    end

    def extract_next_tides(payload)
      data = payload["data"] || []
      now = Time.current
      upcoming = data.select do |entry|
        timestamp = parse_timestamp(entry["time"])
        timestamp.present? && timestamp >= now
      end

      next_high = upcoming.find { |entry| entry["type"].to_s.casecmp("high").zero? }
      next_low = upcoming.find { |entry| entry["type"].to_s.casecmp("low").zero? }

      [value_for(next_high&.dig("time")), value_for(next_low&.dig("time"))]
    end

    WMO_CODES = {
      0 => "Clear sky",
      1 => "Mainly clear", 2 => "Partly cloudy", 3 => "Overcast",
      45 => "Foggy", 48 => "Icy fog",
      51 => "Light drizzle", 53 => "Drizzle", 55 => "Heavy drizzle",
      61 => "Light rain", 63 => "Rain", 65 => "Heavy rain",
      71 => "Light snow", 73 => "Snow", 75 => "Heavy snow",
      77 => "Snow grains",
      80 => "Light showers", 81 => "Showers", 82 => "Heavy showers",
      85 => "Light snow showers", 86 => "Heavy snow showers",
      95 => "Thunderstorm", 96 => "Thunderstorm with hail", 99 => "Thunderstorm with heavy hail"
    }.freeze

    def wmo_description(code)
      return nil if code.nil?

      WMO_CODES[code.to_i]
    end

    def parse_timestamp(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def value_for(value)
      return value["_value"] if value.is_a?(Hash)

      value
    end
  end
end
