class MoonData < ApplicationRecord
  validates :latitude, presence: true
  validates :longitude, presence: true
  validates :api_response, presence: true
end