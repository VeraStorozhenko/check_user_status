class V1::IntegrityLoggerService
    def initialize(user:, status:, source: nil, backend: V1::DatabaseIntegrityLoggerBackend.new)
      @user = user
      @status = status
      @source = source
      @backend = backend
    end
  
    def call
      @backend.log(
        user: @user,
        idfa: @user.idfa,
        ban_status: @status,
        ip: @ip,
        rooted_device: @rooted,
        country: @country,
        proxy: @proxy,
        vpn: @vpn
      )
    end
  end
  