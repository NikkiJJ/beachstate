class CreateBathingSites < ActiveRecord::Migration[7.1]
  def change
    create_table :bathing_sites do |t|
      t.string :site_name, null: false
      t.string :region, null: false
      t.text :description
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.bigint :user_id

      t.timestamps
    end

    add_index :bathing_sites, :user_id
    add_index :bathing_sites, [:site_name, :region]
  end
end
