class CreateTableMoonData < ActiveRecord::Migration[7.2]
  def change
    create_table :moon_data do |t|
      t.string :sign
      t.string :phase
      t.string :special_moon
      t.float :days_until_new_moon
      t.float :days_until_full_moon
      t.jsonb :api_response
      t.float :latitude
      t.float :longitude
      t.timestamps
    end
  end
end
