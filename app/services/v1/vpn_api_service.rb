require 'net/http'
require 'uri'
require 'json'

class V1::VpnApiService
  API_URL = ENV.fetch('VPN_API_URL', 'https://vpnapi.io/api/')
  API_KEY = ENV.fetch('VPN_API_KEY', nil)
  CACHE_EXPIRATION = 24.hours

  def initialize(ip)
    @ip = ip
  end

  def call
    return { error: 'API key missing' } unless API_KEY

    cached = $redis.get(cache_key)
    return JSON.parse(cached) if cached

    uri = URI("#{API_URL}#{@ip}?key=#{API_KEY}")
    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn("VPN API failed for #{@ip}, assuming safe")
      return { security: { vpn: false, proxy: false } }  # Fails open
    end

    data = JSON.parse(response.body)
    $redis.setex("vpnapi:#{@ip}", 24.hours.to_i, response.body)
    data
  rescue StandardError => e
    Rails.logger.error("VPN API error: #{e.message}")
    { security: { vpn: false, proxy: false } } # Fails open
  end

  private

  def cache_key
    "vpn_api_response:#{@ip}"
  end
end
