require 'rails_helper'

RSpec.describe 'V1 user status', type: :request do
  let(:vpn_check) do
    instance_double(V1::VpnApiService, call: { security: { vpn: false, proxy: false, tor: false } })
  end

  before do
    $redis.flushdb
    $redis.sadd("country_whitelist", "US")
    allow(V1::VpnApiService).to receive(:new).and_return(vpn_check)
  end

  describe 'POST /v1/user/check_status' do
    it 'returns the required JSON contract' do
      post '/v1/user/check_status',
           params: { idfa: '8264148c-be95-4b2b-b260-6ee98dd53bf6', rooted_device: false },
           headers: { 'CF-IPCountry' => 'US' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq("ban_status" => "not_banned")
    end

    it 'returns banned when the user fails a check' do
      post '/v1/user/check_status',
           params: { idfa: '8264148c-be95-4b2b-b260-6ee98dd53bf6', rooted_device: true },
           headers: { 'CF-IPCountry' => 'US' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq("ban_status" => "banned")
    end

    it 'rejects a missing idfa' do
      post '/v1/user/check_status',
           params: { rooted_device: false },
           headers: { 'CF-IPCountry' => 'US' },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to eq("error" => "idfa parameter is required")
    end
  end
end
