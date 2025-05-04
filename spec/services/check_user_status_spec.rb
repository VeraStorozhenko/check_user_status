require 'rails_helper'

RSpec.describe V1::CheckUserStatusService do
  let(:user) { User.create!(idfa: "test-idfa") }
  let(:request) do
    instance_double("ActionDispatch::Request",
      remote_ip: "8.8.8.8",
      headers: { "CF-IPCountry" => "US" },
      params: { "rooted_device" => false }
    )
  end

  subject { described_class.new(user: user, request: request) }

  before do
    $redis = Redis.new
    $redis.sadd("country_whitelist", "US")
  end

  it "returns not_banned if all checks pass" do
    allow(request).to receive(:headers).and_return({ "security" => { "vpn" => false, "proxy" => false }} )

    result = subject.call
    expect(result).to eq("not_banned")
  end

  it "returns banned if country is not whitelisted" do
    allow(request).to receive(:headers).and_return({ "CF-IPCountry" => "RU" })

    result = subject.call
    expect(result).to eq("banned")
  end

  it "returns banned if rooted_device is true" do
    allow(request).to receive(:params).and_return({ "rooted_device" => true })

    result = subject.call
    expect(result).to eq("banned")
  end

  it "returns banned if VPN is detected" do
    fake_vpn_info = {
      "security" => {
        "vpn" => true,
        "proxy" => false
      }
    }

    vpn_api_service_double = instance_double(V1::VpnApiService, call: {
      "security" => { "vpn" => true, "proxy" => true }
    })
    allow(V1::VpnApiService).to receive(:new).with(anything).and_return(vpn_api_service_double)

    result = subject.call

    expect(result).to eq("banned")
  end
end