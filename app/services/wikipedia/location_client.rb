require "json"
require "net/http"
require "uri"

module Wikipedia
  class LocationClient
    BASE_URL = "https://en.wikipedia.org/w/api.php".freeze
    CACHE_TTL = 7.days
    READ_TIMEOUT = 10
    THUMBNAIL_WIDTH = 800

    def fetch(site_name:)
      cache_key = "wikipedia:location:#{site_name.downcase.gsub(/\s+/, "_")}"

      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        fetch_live(site_name: site_name)
      end
    end

    private

    def fetch_live(site_name:)
      search_title = find_title(site_name)

      if search_title.blank?
        return { description: nil, image_url: nil, wikipedia_url: nil, unavailable_reason: "No Wikipedia article found for \"#{site_name}\"" }
      end

      fetch_article(title: search_title)
    rescue StandardError => e
      Rails.logger.error("Wikipedia::LocationClient failed for #{site_name}: #{e.class}: #{e.message}")
      { description: nil, image_url: nil, wikipedia_url: nil, unavailable_reason: "Wikipedia request failed" }
    end

    def find_title(site_name)
      uri = URI(BASE_URL)
      uri.query = URI.encode_www_form(
        action: "query",
        list: "search",
        srsearch: site_name,
        srlimit: 1,
        format: "json"
      )

      payload = get_json(uri)
      payload.dig("query", "search", 0, "title")
    end

    def fetch_article(title:)
      uri = URI(BASE_URL)
      uri.query = URI.encode_www_form(
        action: "query",
        titles: title,
        prop: "extracts|pageimages|info",
        exintro: true,
        explaintext: true,
        exsentences: 3,
        piprop: "thumbnail",
        pithumbsize: THUMBNAIL_WIDTH,
        inprop: "url",
        format: "json",
        redirects: 1
      )

      payload = get_json(uri)
      pages = payload.dig("query", "pages") || {}
      page = pages.values.first || {}

      return { description: nil, image_url: nil, wikipedia_url: nil, unavailable_reason: "Article content unavailable" } if page["missing"]

      description = page["extract"].to_s.strip.presence
      image_url = page.dig("thumbnail", "source")
      wikipedia_url = page.dig("fullurl")

      {
        description: description,
        image_url: image_url,
        wikipedia_url: wikipedia_url,
        unavailable_reason: description ? nil : "No description in Wikipedia article"
      }
    end

    def get_json(uri)
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      request["User-Agent"] = "BeachState/1.0 (educational project)"

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: READ_TIMEOUT) do |http|
        http.request(request)
      end

      raise "Unexpected response #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end
  end
end
