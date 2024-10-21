# frozen_string_literal: true

# == Schema Information
#
# Table name: user_totps
#
#  id                :bigint           not null, primary key
#  aasm_state        :string
#  deleted_at        :datetime
#  last_used_at      :datetime
#  secret_ciphertext :text             not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_user_totps_on_user_id  (user_id)
#
class User
  class Totp < ApplicationRecord
    acts_as_paranoid

    include AASM

    aasm do
      state :unverified, initial: true
      state :verified
      state :expired

      event :mark_verified do
        transitions from: :unverified, to: :verified do
          guard do
            created_at > 15.minutes.ago
          end
        end
      end

      event :mark_expired do
        transitions from: :verified, to: :expired
      end
    end

    belongs_to :user
    has_encrypted :secret
    validates :secret, presence: true

    include PublicActivity::Model
    tracked owner: proc{ |controller, record| record.user }, recipient: proc { |controller, record| record.user }, only: [:create]

    before_validation do
      self.secret ||= ROTP::Base32.random
    end

    delegate :verify, to: :instance

    def provisioning_uri
      instance.provisioning_uri(user.email)
    end

    private

    def instance
      ROTP::TOTP.new(secret, issuer: "HCB")
    end

  end

end
