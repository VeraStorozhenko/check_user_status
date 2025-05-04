require 'redis'

  begin
    $redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
    $redis.sadd("country_whitelist", "US", "GB", "DE", "ES", "FR", "IT")
  rescue => e
    Rails.logger.error "Redis connection failed: #{e.message}"
    $redis = nil
  end