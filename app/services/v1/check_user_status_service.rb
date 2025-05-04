class V1::CheckUserStatusService
    def initialize(user:, request:)
      @user = user
      @request = request
      @ip = request.remote_ip
      @headers = request.headers
      @status = "not_banned"
    end
  
    def call
      check_country_whitelist
      check_rooted_device
      check_vpn
    
      @status
    end

    private
  
    def check_country_whitelist
      country = @headers["CF-IPCountry"]
      return if country.blank?
  
      unless $redis.sismember("country_whitelist", country)
        @status = "banned"
      end
    end

    def check_rooted_device
      rooted = @request.params["rooted_device"]
      @status = "banned" if rooted.to_s == "true"      
    end

    def check_vpn
      return if @status == "banned"

      vpn_info = V1::VpnApiService.new(@ip).call
      if vpn_info.present?
        if vpn_info.dig("security", "vpn") || vpn_info.dig("security", "proxy")
          @status = "banned"
        end
      end
    rescue => e
      Rails.logger.warn("VPN API error: #{e.message}")
    end  
  end


