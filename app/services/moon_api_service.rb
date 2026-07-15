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

    # Um 429/5xx traz um corpo JSON sem a chave "error"; sem olhar o status,
    # ele passaria por resposta válida (foi assim que um rate limit virou
    # "não há fase hoje"). Não-2xx vira um hash de erro explícito.
    return conn_response.body if conn_response.success?

    Rails.logger.error("API Consulta Error: HTTP #{conn_response.status} #{conn_response.body.inspect}")
    { error: "HTTP #{conn_response.status}", status: conn_response.status,
      retry_after: conn_response.headers["retry-after"].to_i }

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
