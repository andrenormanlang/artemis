class AddSubscriptionFieldsToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :confirmation_token, :string
    add_column :users, :unsubscribe_token, :string
    add_column :users, :confirmed_at, :datetime
    add_column :users, :unsubscribed_at, :datetime

    add_index :users, :confirmation_token, unique: true
    add_index :users, :unsubscribe_token, unique: true

    # Backfill existing rows: grandfather current users in as confirmed and
    # give them tokens (has_secure_token only generates on create).
    User.reset_column_information
    User.find_each do |user|
      user.update_columns(
        confirmation_token: user.confirmation_token.presence || SecureRandom.base58(24),
        unsubscribe_token: user.unsubscribe_token.presence || SecureRandom.base58(24),
        confirmed_at: user.confirmed_at || Time.current
      )
    end
  end

  def down
    remove_index :users, :confirmation_token
    remove_index :users, :unsubscribe_token
    remove_column :users, :confirmation_token
    remove_column :users, :unsubscribe_token
    remove_column :users, :confirmed_at
    remove_column :users, :unsubscribed_at
  end
end
