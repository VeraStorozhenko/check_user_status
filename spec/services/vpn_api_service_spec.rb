require 'rails_helper'

RSpec.describe V1::VpnApiService, type: :service do
  let(:ip) { '1.2.3.4' }
  let(:api_key) { 'fake_api_key' }
  let(:response_body) do
    {
      security: {
        vpn: true,
        proxy: false,
        tor: false
      }
    }.to_json
  end

  subject(:service) { described_class.new(ip) }

  before do
    stub_const('V1::VpnApiService::API_KEY', api_key)
    $redis.flushdb
  end

  describe '#call' do
    context 'when a cached response exists' do
      before do
        $redis.set("vpnapi:#{ip}", response_body)
      end

      it 'returns the cached response without calling VPNAPI' do
        expect(service.call).to eq(security: { vpn: true, proxy: false, tor: false })
      end
    end

    context 'when VPNAPI returns successfully' do
      before do
        stub_request(:get, "https://vpnapi.io/api/#{ip}?key=#{api_key}")
          .to_return(status: 200, body: response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns parsed JSON with symbol keys' do
        expect(service.call).to eq(security: { vpn: true, proxy: false, tor: false })
      end

      it 'caches the response in Redis for 24 hours' do
        service.call

        expect(JSON.parse($redis.get("vpnapi:#{ip}"))).to eq(
          "security" => {
            "vpn" => true,
            "proxy" => false,
            "tor" => false
          }
        )
        expect($redis.ttl("vpnapi:#{ip}")).to be_between(86_300, 86_400)
      end
    end

    context 'when VPNAPI returns an error' do
      before do
        stub_request(:get, "https://vpnapi.io/api/#{ip}?key=#{api_key}")
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'fails open' do
        expect(service.call).to eq(security: { vpn: false, proxy: false, tor: false })
      end
    end

    context 'when the request raises' do
      before do
        stub_request(:get, "https://vpnapi.io/api/#{ip}?key=#{api_key}")
          .to_raise(Timeout::Error)
      end

      it 'fails open' do
        expect(service.call).to eq(security: { vpn: false, proxy: false, tor: false })
      end
    end

    context 'when the API key is missing' do
      let(:api_key) { nil }

      it 'fails open' do
        expect(service.call).to eq(security: { vpn: false, proxy: false, tor: false })
      end
    end
  end
end
