
class V1::DatabaseIntegrityLoggerBackend
  def log(user:, idfa:, ban_status:, ip:, rooted_device:, country:, proxy:, vpn:)
    IntegrityLog.create!(
      user: user,
      idfa: idfa,
      ban_status: ban_status,
      ip: ip,
      rooted_device: rooted_device,
      country: country,
      proxy: proxy,
      vpn: vpn
    )
  end
end

