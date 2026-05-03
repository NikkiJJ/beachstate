require "json"
require "net/http"
require "uri"
require "time"

module EnvironmentAgency
  class BathingWaterClient
    BASE_URL = "https://environment.data.gov.uk/doc/bathing-water.json".freeze
    CACHE_KEY = "environment_agency:bathing_water:sites:v1".freeze
    PAGE_SIZE = 200
    READ_TIMEOUT = 15

    def list_sites(query: nil)
      sites = Rails.cache.fetch(CACHE_KEY, expires_in: 6.hours) do
        fetch_all_sites
      end

      return sites if query.blank?

      q = query.to_s.downcase
      sites.select do |site|
        [site[:site_name], site[:region], site[:quality_classification]].compact.any? do |value|
          value.downcase.include?(q)
        end
      end
    end

    private

    def fetch_all_sites
      endpoint = URI(BASE_URL)
      endpoint.query = URI.encode_www_form(_page: 0, _pageSize: PAGE_SIZE)
      fetched_at = Time.current.iso8601

      sites = []
      visited = 0

      while endpoint.present? && visited < 20
        payload = get_json(endpoint)
        items = payload.dig("result", "items") || []
        sites.concat(items.filter_map { |item| map_item(item, fetched_at: fetched_at) })

        next_url = payload.dig("result", "next")
        endpoint = next_url.present? ? URI(next_url) : nil
        visited += 1
      end

      sites.uniq { |site| site[:id] }.sort_by { |site| site[:site_name] }
    rescue StandardError => e
      Rails.logger.error("BathingWaterClient fetch failed: #{e.class}: #{e.message}")
      []
    end

    def get_json(uri)
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: READ_TIMEOUT) do |http|
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise "Unexpected response #{response.code} for #{uri}"
      end

      JSON.parse(response.body)
    end

    def map_item(item, fetched_at:)
      code = item["eubwidNotation"].presence || item["_about"].to_s.split("/").last
      return nil if code.blank?

      site_name = value_for(item["name"])
      return nil if site_name.blank?

      region = parse_region(item)

      quality_name = value_for(item.dig("latestComplianceAssessment", "complianceClassification", "name"))
      quality_href = item.dig("latestComplianceAssessment", "complianceClassification", "_about")
      risk_level = value_for(item.dig("latestRiskPrediction", "riskLevel", "name"))
      risk_expires_at = value_for(item.dig("latestRiskPrediction", "expiresAt"))
      latest_sample_at = extract_latest_sample_at(item)
      latest_risk_prediction_at = extract_latest_risk_prediction_at(item)
      source_updated_at = latest_sample_at || latest_risk_prediction_at

      lat = item.dig("samplingPoint", "lat")
      long = item.dig("samplingPoint", "long")

      {
        id: code,
        site_name: site_name,
        region: region,
        country: value_for(item.dig("country", "name")),
        description: description_for(item),
        latitude: lat,
        longitude: long,
        location_label: [site_name, region].compact_blank.join(", "),
        quality_classification: quality_name,
        quality_classification_uri: quality_href,
        latest_sample_at: latest_sample_at,
        latest_risk_prediction_at: latest_risk_prediction_at,
        source_updated_at: source_updated_at,
        risk_level: risk_level,
        risk_prediction_expires_at: risk_expires_at,
        year_designated: item["yearDesignated"],
        cache_refreshed_at: fetched_at,
        official_uri: item["_about"],
        eubwid_notation: code,
        heavy_rain_affected: item["waterQualityImpactedByHeavyRain"],
        created_at: nil,
        updated_at: nil
      }
    end

    def parse_region(item)
      district = item["district"]

      if district.is_a?(Array)
        named = district.find { |entry| entry.is_a?(Hash) && entry["name"].present? }
        return value_for(named["name"]) if named
      elsif district.is_a?(Hash)
        value = value_for(district["name"])
        return value if value.present?
      end

      value_for(item.dig("regionalOrganization", "name")) || "Unknown region"
    end

    def description_for(item)
      heavy_rain = item["waterQualityImpactedByHeavyRain"]
      return nil if heavy_rain.nil?

      if heavy_rain
        "Water quality can be impacted by heavy rainfall."
      else
        "No heavy rainfall impact flag on the latest profile."
      end
    end

    def value_for(value)
      return value["_value"] if value.is_a?(Hash)

      value
    end

    def extract_latest_sample_at(item)
      latest_sample_uri = item["latestSampleAssessment"].to_s
      return nil if latest_sample_uri.blank?

      date = latest_sample_uri[/\/date\/(\d{8})/, 1]
      time = latest_sample_uri[/\/time\/(\d{6})/, 1]

      if date.present? && time.present?
        return Time.zone.strptime("#{date}#{time}", "%Y%m%d%H%M%S").iso8601
      end

      return Time.zone.strptime(date, "%Y%m%d").iso8601 if date.present?

      nil
    rescue ArgumentError
      nil
    end

    def extract_latest_risk_prediction_at(item)
      risk_uri = item.dig("latestRiskPrediction", "_about").to_s
      return nil if risk_uri.blank?

      datetime = risk_uri[/\/date\/(\d{8}-\d{6})/, 1]
      return nil if datetime.blank?

      Time.zone.strptime(datetime, "%Y%m%d-%H%M%S").iso8601
    rescue ArgumentError
      nil
    end
  end
end
