require "net/http"
require "uri"
require "json"

class V1::VpnApiService
  API_URL = ENV.fetch("VPN_API_URL", "https://vpnapi.io/api/")
  API_KEY = ENV.fetch("VPN_API_KEY", nil)
  CACHE_EXPIRATION = 24.hours
  SAFE_RESPONSE = { security: { vpn: false, proxy: false, tor: false } }.freeze

  def initialize(ip)
    @ip = ip
  end

  def call
    return SAFE_RESPONSE unless API_KEY.present?

    cached = $redis&.get(cache_key)
    return JSON.parse(cached, symbolize_names: true) if cached

    uri = URI("#{API_URL}#{@ip}?key=#{API_KEY}")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 2, read_timeout: 2) do |http|
      http.request(Net::HTTP::Get.new(uri))
    end

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn("VPN API failed for #{@ip}, assuming safe")
      return SAFE_RESPONSE
    end

    data = JSON.parse(response.body, symbolize_names: true)
    $redis&.setex(cache_key, CACHE_EXPIRATION.to_i, data.to_json)
    data
  rescue StandardError => e
    Rails.logger.error("VPN API error: #{e.message}")
    SAFE_RESPONSE
  end

  private

  def cache_key
    "vpnapi:#{@ip}"
  end
end
