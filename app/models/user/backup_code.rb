# frozen_string_literal: true

# == Schema Information
#
# Table name: user_backup_codes
#
#  id         :bigint           not null, primary key
#  aasm_state :string
#  code_hash  :text             not null
#  salt       :text             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_user_backup_codes_on_code_hash  (code_hash) UNIQUE
#  index_user_backup_codes_on_user_id    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class User
  class BackupCode < ApplicationRecord
    has_paper_trail

    include AASM

    belongs_to :user

    validates :code_hash, presence: true, uniqueness: true

    aasm do
      state :previewed, initial: true
      state :active
      state :used
      state :discarded

      event :mark_active do
        transitions from: :previewed, to: :active
      end
      event :mark_used do
        transitions from: :active, to: :used

        after do
          case user.backup_codes.active.size
          when 0
            User::BackupCodeMailer.with(user_id: user.id).no_codes_remaining.deliver_now
          when 1..3
            User::BackupCodeMailer.with(user_id: user.id).three_or_fewer_codes_left.deliver_now
          end
          User::BackupCodeMailer.with(user_id: user.id).code_used.deliver_now
        end
      end
      event :mark_discarded do
        transitions from: [:active, :previewed], to: :discarded
      end
    end

    def self.gen_hash(code:, salt:, pepper:)
      OpenSSL::KDF.pbkdf2_hmac(code + pepper, hash: "sha512", salt: Base64.decode64(salt), iterations: 20_000, length: 64).unpack1("H*")
    end

  end

end
