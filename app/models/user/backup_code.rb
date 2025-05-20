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
      state :unsaved, initial: true
      state :unused
      state :used
      state :invalidated

      event :mark_unused do
        transitions from: :unsaved, to: :unused
      end
      event :mark_used do
        transitions from: :unused, to: :used

        after do
          case user.backup_codes.unused.size
          when 0
            User::BackupCodeMailer.with(user_id: user.id).no_codes_remaining.deliver_now
          when 1..3
            User::BackupCodeMailer.with(user_id: user.id).two_or_fewer_codes_left.deliver_now
          end
          User::BackupCodeMailer.with(user_id: user.id).code_used.deliver_now
        end
      end
      event :mark_invalidated do
        transitions from: [:unused, :unsaved], to: :invalidated
      end
    end

    def self.gen_hash(code:, salt:, pepper:)
      OpenSSL::KDF.pbkdf2_hmac(code + pepper, hash: "sha512", salt: Base64.decode64(salt), iterations: 20_000, length: 64).unpack1("H*")
    end

  end

end
