class MoonsController < ApplicationController
  def index
    if params[:lat] && params[:lng]
      session[:latitude] = params[:lat]
      session[:longitude] = params[:lng]

      @last_checked_moon = last_checked_moon

      render :index
    elsif session[:latitude] && session[:longitude]
      @last_checked_moon = last_checked_moon

      render :index
    else
      render :loading_location
    end
  end

  private

  def last_checked_moon
    stockholm_today = Time.find_zone!("Europe/Stockholm").today
    moon_data = MoonData.find_by(latitude: session[:latitude],
                               longitude: session[:longitude],
                               created_at: stockholm_today.beginning_of_day..stockholm_today.end_of_day)
    if moon_data.present?
      moon_data_presenter(moon_data.api_response)
    else
      api_response = moon_api_data
      presenter = moon_data_presenter(api_response)
      MoonData.create(presenter)
      presenter
    end
  end

  def moon_api_data
    stockholm_today = Time.find_zone!("Europe/Stockholm").today
    moon_params = {
      "lat" => session[:latitude],
      "lon" => session[:longitude],
      "include_visuals" => true,
      "include_zodiac" => true,
      "include_special" => true
    }

    MoonApiService.new(stockholm_today, moon_params).call
  end


  def moon_data_presenter(moon_data)
    Rails.logger.info("Moon API Response: #{moon_data.inspect}")
    MoonData::Index.new(moon_data.with_indifferent_access, latitude: session[:latitude], longitude: session[:longitude]).present
  end
end
