require "faraday"

class MoonApiService
  def initialize(date, params = {})
    @params = params
    @date = date
  end

  def call
    connection = Faraday.new(url: ENV["DAILY_LUNAR_API_URL"]) do |faraday|
      faraday.request :url_encoded
      faraday.response :logger, Rails.logger
      faraday.response :json, content_type: /\bjson$/
      faraday.adapter Faraday.default_adapter
    end
    conn_response = connection.get do |req|
      req.params = request_params
      req.headers["x-api-key"] = ENV["ASTRO_API_KEY"]
    end
    conn_response.body

  rescue Faraday::Error => e
    log_error(e)
    { error: e.message }
  end

  private

  def log_error(error)
    Rails.logger.error("API Consulta Error: #{error.message}")
  end

  def request_params
    @params.merge("date" => @date.strftime("%Y-%m-%dT%H:%M:%S"))
  end
end
