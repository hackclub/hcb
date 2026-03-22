# frozen_string_literal: true

# == Schema Information
#
# Table name: user_backup_codes
#
#  id          :bigint           not null, primary key
#  aasm_state  :string           default("previewed"), not null
#  code_digest :text             not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_user_backup_codes_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class User
  class BackupCode < ApplicationRecord
    has_paper_trail

    has_secure_password :code

    include AASM

    belongs_to :user

    validates :code_digest, presence: true

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
          User::BackupCodeMailer.with(user_id: user.id).code_used.deliver_now
        end
      end
      event :mark_discarded do
        transitions from: :active, to: :discarded
      end
    end

  end

end
