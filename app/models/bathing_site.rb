class BathingSite < ApplicationRecord
  belongs_to :user, optional: true

  validates :site_name, presence: true
  validates :region, presence: true

  scope :search_text, ->(term) do
    next all if term.blank?

    q = "%#{sanitize_sql_like(term.to_s.downcase)}%"
    where("LOWER(site_name) LIKE :q OR LOWER(region) LIKE :q", q: q)
  end

  def location_label
    [site_name, region].compact_blank.join(", ")
  end
end
