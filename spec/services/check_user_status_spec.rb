require 'rails_helper'

RSpec.describe CheckUserStatusService, type: :service do
  let(:idfa) { "test-idfa-12345" }
  let(:rooted_device) { false }
  let(:vpn_api_service) { class_double(V1::VpnApiService) }
  let(:vpn_api_response) { { security: { vpn: false, proxy: false, tor: false } } }
  let(:vpn_check) { instance_double(V1::VpnApiService, call: vpn_api_response) }
  let(:request) do
    instance_double(
      "ActionDispatch::Request",
      remote_ip: "8.8.8.8",
      headers: { "CF-IPCountry" => "US" }
    )
  end

  subject(:service) do
    described_class.new(
      idfa: idfa,
      rooted_device: rooted_device,
      request: request,
      vpn_api_service: vpn_api_service
    )
  end

  before do
    $redis.flushdb
    $redis.sadd("country_whitelist", "US")
    allow(vpn_api_service).to receive(:new).with("8.8.8.8").and_return(vpn_check)
  end

  describe '#call' do
    context 'when all checks pass' do
      it 'returns not_banned, creates the user, and writes an integrity log' do
        expect {
          expect(service.call).to eq("not_banned")
        }.to change(User, :count).by(1).and change(IntegrityLog, :count).by(1)

        expect(User.last.ban_status).to eq("not_banned")
        expect(IntegrityLog.last).to have_attributes(
          idfa: idfa,
          ban_status: "not_banned",
          ip: "8.8.8.8",
          country: "US",
          rooted_device: false,
          proxy: false,
          vpn: false
        )
      end
    end

    context 'when the Cloudflare country is not whitelisted' do
      let(:request) do
        instance_double(
          "ActionDispatch::Request",
          remote_ip: "8.8.8.8",
          headers: { "CF-IPCountry" => "RU" }
        )
      end

      it 'bans the user without calling VPNAPI' do
        expect(vpn_api_service).not_to receive(:new)

        expect {
          expect(service.call).to eq("banned")
        }.to change(User, :count).by(1).and change(IntegrityLog, :count).by(1)

        expect(User.last.ban_status).to eq("banned")
      end
    end

    context 'when the Cloudflare country header is missing' do
      let(:request) do
        instance_double(
          "ActionDispatch::Request",
          remote_ip: "8.8.8.8",
          headers: {}
        )
      end

      it 'bans the user' do
        expect(service.call).to eq("banned")
        expect(User.last.ban_status).to eq("banned")
      end
    end

    context 'when the device is rooted' do
      let(:rooted_device) { "true" }

      it 'bans the user without calling VPNAPI' do
        expect(vpn_api_service).not_to receive(:new)

        expect {
          expect(service.call).to eq("banned")
        }.to change(User, :count).by(1).and change(IntegrityLog, :count).by(1)

        expect(IntegrityLog.last.rooted_device).to eq(true)
      end
    end

    context 'when VPNAPI detects a VPN' do
      let(:vpn_api_response) { { security: { vpn: true, proxy: false, tor: false } } }

      it 'bans the user and records the VPN flag' do
        expect(service.call).to eq("banned")
        expect(IntegrityLog.last.vpn).to eq(true)
      end
    end

    context 'when VPNAPI detects a proxy' do
      let(:vpn_api_response) { { security: { vpn: false, proxy: true, tor: false } } }

      it 'bans the user and records the proxy flag' do
        expect(service.call).to eq("banned")
        expect(IntegrityLog.last.proxy).to eq(true)
      end
    end

    context 'when VPNAPI detects Tor' do
      let(:vpn_api_response) { { security: { vpn: false, proxy: false, tor: true } } }

      it 'bans the user' do
        expect(service.call).to eq("banned")
      end
    end

    context 'when the user is already banned' do
      it 'returns banned and skips the check chain and duplicate log' do
        User.create!(idfa: idfa, ban_status: "banned")
        expect(vpn_api_service).not_to receive(:new)

        expect {
          expect(service.call).to eq("banned")
        }.not_to change(IntegrityLog, :count)
      end
    end

    context 'when an existing not_banned user returns' do
      it 're-runs checks and logs only if status changes' do
        User.create!(idfa: idfa, ban_status: "not_banned")

        expect {
          expect(service.call).to eq("not_banned")
        }.not_to change(IntegrityLog, :count)
      end

      context 'and now fails a check' do
        let(:vpn_api_response) { { security: { vpn: true, proxy: false, tor: false } } }

        it 'updates the user and logs the status change' do
          User.create!(idfa: idfa, ban_status: "not_banned")

          expect {
            expect(service.call).to eq("banned")
          }.to change(IntegrityLog, :count).by(1)

          expect(User.find_by!(idfa: idfa).ban_status).to eq("banned")
        end
      end
    end
  end
end
