require 'rails_helper'
require 'webmock/rspec'

RSpec.describe V1::VpnApiService do
    let(:ip) { '1.2.3.4' }
    subject { described_class.new(ip) }
  
    let(:response_body) do
      {
        security: {
          vpn: true,
          proxy: false
        }
      }.to_json
    end
  
    before do
      stub_const('V1::VpnApiService::API_KEY', 'fake_api_key')
      $redis.flushdb
    end
  
    describe '#call' do
      context 'when API call is successful' do
        before do
          stub_request(:get, "https://vpnapi.io/api/#{ip}?key=fake_api_key")
            .to_return(status: 200, body: response_body, headers: { 'Content-Type' => 'application/json' })
        end
  
        it 'returns parsed JSON data' do
          result = subject.call
          expect(result).to eq( {"security"=>{"proxy"=>false, "vpn"=>true}})
        end
  
        it 'caches the response in Redis' do
          expect($redis.get("vpnapi:#{ip}")).to be_nil
          subject.call
          expect($redis.get("vpnapi:#{ip}")).to eq(response_body)
        end
      end
  
      context 'when VPN API is unavailable (500)' do
        before do
          stub_request(:get, "https://vpnapi.io/api/#{ip}?key=fake_api_key")
            .to_return(status: 500, body: 'Internal Server Error')
        end
  
        it 'returns default response as passed check' do
          expect(subject.call).to eq({ security: { vpn: false, proxy: false } })
        end
      end
  
      context 'when an exception occurs' do
        before do
          stub_request(:get, "https://vpnapi.io/api/#{ip}?key=fake_api_key")
            .to_raise(Timeout::Error)
        end
  
        it 'returns default response as passed check' do
          expect(subject.call).to eq({ security: { vpn: false, proxy: false } })
        end
      end
  
      context 'when API key is missing' do
        before do
          stub_const('V1::VpnApiService::API_KEY', nil)
        end
  
        it 'returns error indicating missing API key' do
          expect(subject.call).to eq({ error: 'API key missing' })
        end
      end
    end
  end
# require 'rails_helper'
# require 'webmock/rspec'

# RSpec.describe V1::VpnApiService do
#   let(:ip) { '8.8.8.8' }
#   let(:api_url) { "https://vpnapi.io/api/#{ip}?key=#{api_key}" }

#   subject { described_class.new(ip) }

#   describe '#call' do
#     context 'when API key is missing' do
#       before do
#         stub_const('V1::VpnApiService::API_KEY', nil)
#       end

#       it 'returns an error' do
#         expect(subject.call).to eq({ error: 'API key missing' })
#       end
#     end

#     context 'when API call is successful' do
#       let(:api_key) { 'test_key' }

#       before do
#         stub_const('V1::VpnApiService::API_KEY', api_key)
#         stub_request(:get, api_url)
#           .to_return(status: 200, body: { security: { vpn: true } }.to_json, headers: { 'Content-Type' => 'application/json' })
#       end

#       it 'returns parsed JSON data' do
#         result = subject.call
#         expect(result).to eq({ 'security' => { 'vpn' => true } })
#       end
#     end

#     context 'when VPN API is unavailable (e.g. 500)' do
#       let(:api_key) { 'test_key' }

#       before do
#         stub_const('V1::VpnApiService::API_KEY', api_key)
#         stub_request(:get, api_url)
#           .to_return(status: 500, body: 'Internal Server Error')
#       end

#       it 'returns an error' do
#         expect(subject.call).to eq({ error: 'VPN API unavailable' })
#       end
#     end

#     context 'when an exception occurs (e.g. timeout)' do
#       let(:api_key) { 'test_key' }

#       before do
#         stub_const('V1::VpnApiService::API_KEY', api_key)
#         stub_request(:get, api_url).to_raise(SocketError.new('Failed to open TCP connection'))
#       end

#       it 'returns a request failed error' do
#         expect(subject.call).to eq({ error: 'VPN API request failed' })
#       end
#     end
#   end
# end