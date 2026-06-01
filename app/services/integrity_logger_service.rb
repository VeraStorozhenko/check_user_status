class IntegrityLoggerService
  attr_reader :user, :ban_status, :context, :rooted_device, :backend

  def initialize(user:, ban_status:, context:, rooted_device:, backend: V1::DatabaseIntegrityLoggerBackend.new)
    @user = user
    @ban_status = ban_status
    @context = context
    @rooted_device = rooted_device
    @backend = backend
  end

  def call
    backend.log(
      user: user,
      idfa: user.idfa,
      ban_status: ban_status,
      ip: context[:ip],
      rooted_device: rooted_device == true,
      country: context[:country],
      proxy: context[:proxy] || false,
      vpn: context[:vpn] || false
    )
  end
end
