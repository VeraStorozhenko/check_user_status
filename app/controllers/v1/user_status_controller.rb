module V1
  class UserStatusController < ApplicationController
    def check
      user = User.find_or_create_by(idfa: params[:idfa])
      result = CheckUserStatusService.new(user: user, request: request).call
      IntegrityLoggerService.new(user: user, status: status, source: 'api').call
      render json: { ban_status: result }
    end
  end
end
