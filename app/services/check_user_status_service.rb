require "ipaddr"

class CheckUserStatusService
  attr_reader :idfa, :rooted_device, :request, :context

  def initialize(idfa:, rooted_device:, request:, vpn_api_service: V1::VpnApiService)
    @idfa = idfa
    @rooted_device = ActiveModel::Type::Boolean.new.cast(rooted_device)
    @request = request
    @vpn_api_service = vpn_api_service
    @context = {
      ip: request.remote_ip,
      country: request.headers["CF-IPCountry"].to_s.upcase.presence,
      proxy: false,
      vpn: false
    }
  end

  def call
    User.transaction do
      user = User.lock.find_or_initialize_by(idfa: idfa)
      is_new_record = user.new_record?

      if !is_new_record && user.ban_status == "banned"
        return "banned"
      end

      final_status = run_security_checks? ? "banned" : "not_banned"

      status_changed = is_new_record || user.ban_status != final_status
      user.ban_status = final_status
      user.save!

      if status_changed
        IntegrityLoggerService.new(
          user: user,
          ban_status: final_status,
          context: context,
          rooted_device: rooted_device
        ).call
      end

      final_status
    end
  end

  private

  attr_reader :vpn_api_service

  def run_security_checks?
    if context[:country].blank? || !$redis&.sismember("country_whitelist", context[:country].to_s.upcase)
      return true
    end

    return true if rooted_device == true
    return true if vpn_or_proxy_detected?

    false
  end

  def vpn_or_proxy_detected?
    return false if context[:ip].blank? || loopback_ip?

    api_response = vpn_api_service.new(context[:ip]).call
    security = api_response[:security] || {}
    context[:proxy] = security[:proxy] == true
    context[:vpn] = security[:vpn] == true

    security[:vpn] == true || security[:proxy] == true || security[:tor] == true
  end

  def loopback_ip?
    IPAddr.new(context[:ip]).loopback?
  rescue IPAddr::InvalidAddressError
    false
  end
end
