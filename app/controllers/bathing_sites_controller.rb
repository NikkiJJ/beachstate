class BathingSitesController < ApplicationController
  before_action :set_bathing_site, only: [:show, :update]

  def index
    sites = EnvironmentAgency::BathingWaterClient.new.list_sites(query: params[:q])
    render json: sites
  rescue StandardError => e
    Rails.logger.error("Failed to load Environment Agency bathing sites: #{e.class}: #{e.message}")
    render json: { errors: ["Unable to load official bathing water data right now."] }, status: :service_unavailable
  end

  def show
    render json: bathing_site_json(@bathing_site)
  end

  def create
    bathing_site = BathingSite.new(bathing_site_params)

    if bathing_site.save
      render json: bathing_site_json(bathing_site), status: :created
    else
      render json: { errors: bathing_site.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @bathing_site.update(bathing_site_params)
      render json: bathing_site_json(@bathing_site)
    else
      render json: { errors: @bathing_site.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def wiki
    site_name = params[:site_name].to_s.strip

    if site_name.blank?
      render json: { errors: ["site_name is required"] }, status: :unprocessable_entity
      return
    end

    payload = Wikipedia::LocationClient.new.fetch(site_name: site_name)
    render json: payload
  rescue StandardError => e
    Rails.logger.error("Failed to load Wikipedia info: #{e.class}: #{e.message}")
    render json: { errors: ["Unable to load location info right now."] }, status: :service_unavailable
  end

  def weather
    latitude = parse_coordinate(params[:lat])
    longitude = parse_coordinate(params[:lng])

    if latitude.nil? || longitude.nil?
      render json: { errors: ["lat and lng are required numeric params"] }, status: :unprocessable_entity
      return
    end

    payload = Stormglass::MarineClient.new.current_conditions(latitude: latitude, longitude: longitude)
    render json: payload
  rescue StandardError => e
    Rails.logger.error("Failed to load Stormglass conditions: #{e.class}: #{e.message}")
    render json: { errors: ["Unable to load weather data right now."] }, status: :service_unavailable
  end

  private

  def set_bathing_site
    @bathing_site = BathingSite.find(params[:id])
  end

  def bathing_site_params
    params.require(:bathing_site).permit(:site_name, :region, :description)
  end

  def bathing_site_json(site)
    {
      id: site.id,
      site_name: site.site_name,
      region: site.region,
      description: site.description,
      latitude: site.latitude,
      longitude: site.longitude,
      location_label: site.location_label,
      created_at: site.created_at,
      updated_at: site.updated_at
    }
  end

  def parse_coordinate(value)
    return nil if value.blank?

    Float(value)
  rescue ArgumentError, TypeError
    nil
  end
end
