class BathingSitesController < ApplicationController
  before_action :set_bathing_site, only: [:show, :update]

  def index
    sites = BathingSite.order(created_at: :desc)
    sites = sites.search_text(params[:q]) if params[:q].present?

    render json: sites.map { |site| bathing_site_json(site) }
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
end
