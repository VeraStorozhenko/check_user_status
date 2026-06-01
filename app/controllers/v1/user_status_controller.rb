module V1
  class UserStatusController < ApplicationController
    def check
      if params[:idfa].blank?
        return render json: { error: "idfa parameter is required" }, status: :unprocessable_entity
      end

      result = CheckUserStatusService.new(
        idfa: params[:idfa],
        rooted_device: params[:rooted_device],
        request: request
      ).call

      render json: { ban_status: result }, status: :ok
    end
  end
end
