require 'rails_helper'

RSpec.describe V1::IntegrityLoggerService do
  let(:user) { User.create!(idfa: "test-idfa") }
  let(:status) { 'active' }
  let(:source) { 'test_source' }
  let(:mock_backend) { MockIntegrityLoggerBackend.new }

  class MockIntegrityLoggerBackend
    attr_reader :logged_data

    def log(**kwargs)
      @logged_data = kwargs
    end
  end

  describe 'with testable subclass' do
    class TestableIntegrityLoggerService < V1::IntegrityLoggerService
      def initialize(user:, status:, backend:)
        super
        @ip = '127.0.0.1'
        @rooted = false
        @country = 'ES'
        @proxy = true
        @vpn = false
      end
    end

    subject do
      TestableIntegrityLoggerService.new(
        user: user,
        status: status,
        backend: mock_backend
      )
    end

    it 'delegates logging to the backend with correct data' do
      subject.call

      expect(mock_backend.logged_data).to eq(
        user: user,
        idfa: 'test-idfa',
        ban_status: 'active',
        ip: '127.0.0.1',
        rooted_device: false,
        country: 'ES',
        proxy: true,
        vpn: false
      )
    end
  end

  describe 'with real backend' do
    subject { described_class.new(user: user, status: status, source: source) }

    describe '#initialize' do
      it 'sets the user' do
        expect(subject.instance_variable_get(:@user)).to eq(user)
      end

      it 'sets the status' do
        expect(subject.instance_variable_get(:@status)).to eq(status)
      end

      it 'sets the source' do
        expect(subject.instance_variable_get(:@source)).to eq(source)
      end
    end

    describe '#call' do
      it 'creates an IntegrityLog record' do
        expect { subject.call }.to change(IntegrityLog, :count).by(1)
      end

      it 'sets nil values in the IntegrityLog by default' do
        subject.call
        integrity_log = IntegrityLog.last

        expect(integrity_log.user).to eq(user)
        expect(integrity_log.idfa).to eq(user.idfa)
        expect(integrity_log.ban_status).to eq(status)
        expect(integrity_log.ip).to be_nil
        expect(integrity_log.rooted_device).to be_nil
        expect(integrity_log.country).to be_nil
        expect(integrity_log.proxy).to be_nil
        expect(integrity_log.vpn).to be_nil
      end
    end
  end
end
