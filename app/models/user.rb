class User < ApplicationRecord
  has_many :integrity_logs, dependent: :destroy

  enum :ban_status, {
    banned: "banned",
    not_banned: "not_banned"
  }, default: :not_banned

  validates :idfa, presence: true, uniqueness: true
  validates :ban_status, presence: true
end
