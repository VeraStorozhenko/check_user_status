class User < ApplicationRecord
  has_many :integrity_logs, dependent: :destroy

  enum ban_status: {
    active: 'active',
    temporarily_banned: 'temporarily_banned',
    permanently_banned: 'permanently_banned',
    under_review: 'under_review'
  }, _suffix: true
end
