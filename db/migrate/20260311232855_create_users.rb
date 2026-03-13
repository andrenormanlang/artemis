class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :name
      t.float :latitude
      t.float :longitude
      t.string :email

      t.timestamps
    end
  end
end
