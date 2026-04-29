# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

sample_bathing_sites = [
	{
		site_name: "Porthminster Beach",
		region: "Cornwall",
		description: "Family-friendly sandy beach close to St Ives town.",
		latitude: 50.197132,
		longitude: -5.463714
	},
	{
		site_name: "West Wittering Beach",
		region: "West Sussex",
		description: "Wide beach with dunes and shallow water.",
		latitude: 50.764871,
		longitude: -0.883508
	},
	{
		site_name: "Whitby Beach",
		region: "North Yorkshire",
		description: "Popular coastal bathing site beneath Whitby Abbey cliffs.",
		latitude: 54.487964,
		longitude: -0.610504
	},
	{
		site_name: "Bournemouth Pier Beach",
		region: "Dorset",
		description: "Long sandy stretch near town center and pier.",
		latitude: 50.716098,
		longitude: -1.874648
	},
	{
		site_name: "Portobello Beach",
		region: "Edinburgh",
		description: "Urban beach with promenade on the Firth of Forth.",
		latitude: 55.951111,
		longitude: -3.114167
	}
]

sample_bathing_sites.each do |attrs|
	site = BathingSite.find_or_initialize_by(site_name: attrs[:site_name], region: attrs[:region])
	site.assign_attributes(attrs)
	site.save!
end

puts "Seeded #{sample_bathing_sites.size} bathing sites."
