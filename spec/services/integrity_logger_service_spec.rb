require 'rails_helper'

RSpec.describe IntegrityLoggerService, type: :service do
  let(:user) { User.create!(idfa: "test-idfa-123", ban_status: "not_banned") }

  let(:context) do
    {
      ip: '127.0.0.1',
      country: 'ES',
      proxy: true,
      vpn: false
    }
  end
  let(:rooted_device) { false }
  let(:ban_status) { 'not_banned' }
  let(:backend) { V1::DatabaseIntegrityLoggerBackend.new }

  subject do
    described_class.new(
      user: user,
      ban_status: ban_status,
      context: context,
      rooted_device: rooted_device,
      backend: backend
    )
  end

  describe '#initialize' do
    it 'correctly assigns all passed instance variables' do
      expect(subject.instance_variable_get(:@user)).to eq(user)
      expect(subject.instance_variable_get(:@ban_status)).to eq(ban_status)
      expect(subject.instance_variable_get(:@context)).to eq(context)
      expect(subject.instance_variable_get(:@rooted_device)).to eq(rooted_device)
      expect(subject.instance_variable_get(:@backend)).to eq(backend)
    end
  end

  describe '#call' do
    it 'delegates logging to the configured backend' do
      mock_backend = instance_double(V1::DatabaseIntegrityLoggerBackend)
      service = described_class.new(
        user: user,
        ban_status: ban_status,
        context: context,
        rooted_device: rooted_device,
        backend: mock_backend
      )

      expect(mock_backend).to receive(:log).with(
        user: user,
        idfa: user.idfa,
        ban_status: ban_status,
        ip: '127.0.0.1',
        rooted_device: false,
        country: 'ES',
        proxy: true,
        vpn: false
      )

      service.call
    end

    it 'successfully creates a new record in the integrity_logs table' do
      expect { subject.call }.to change(IntegrityLog, :count).by(1)
    end

    it 'accurately persists metadata from user and context into PostgreSQL' do
      subject.call
      log = IntegrityLog.last

      expect(log.user).to eq(user)
      expect(log.idfa).to eq("test-idfa-123")
      expect(log.ban_status).to eq('not_banned')
      expect(log.ip).to eq('127.0.0.1')
      expect(log.country).to eq('ES')
      expect(log.rooted_device).to eq(false)
      expect(log.proxy).to eq(true)
      expect(log.vpn).to eq(false)
    end

    it 'safely fallbacks nil proxy or vpn values to false to prevent NotNullViolations' do
      nil_context_service = described_class.new(
        user: user,
        ban_status: 'banned',
        context: { ip: '8.8.8.8', country: 'US', proxy: nil, vpn: nil },
        rooted_device: true
      )

      nil_context_service.call
      log = IntegrityLog.last

      expect(log.proxy).to eq(false)
      expect(log.vpn).to eq(false)
      expect(log.rooted_device).to eq(true)
      expect(log.ban_status).to eq('banned')
    end
  end
end
