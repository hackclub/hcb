# frozen_string_literal: true

# == Schema Information
#
# Table name: user_email_updates
#
#  id                  :bigint           not null, primary key
#  aasm_state          :string           not null
#  authorization_token :string           not null
#  authorized          :boolean          default(FALSE), not null
#  original            :string           not null
#  replacement         :string           not null
#  verification_token  :string           not null
#  verified            :boolean          default(FALSE), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  updated_by_id       :bigint
#  user_id             :bigint           not null
#
# Indexes
#
#  index_user_email_updates_on_updated_by_id  (updated_by_id)
#  index_user_email_updates_on_user_id        (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (updated_by_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
class User
  class EmailUpdate < ApplicationRecord
    include AASM
    has_paper_trail

    EXPIRATION = 15.minutes

    scope :active, -> { where(aasm_state: :requested, created_at: EXPIRATION.ago..) }

    belongs_to :user
    belongs_to :updated_by, class_name: "User"
    has_secure_token :authorization_token
    has_secure_token :verification_token

    validate :non_hcb_email
    validate :non_existing_email

    after_create_commit do
      user.email_updates.requested.excluding(self).each(&:mark_stale!)
      send_emails unless confirmed?
    end

    before_save do
      if updated_by.admin? && updated_by != user
        assign_attributes(authorized: true, verified: true)
      end
      mark_confirmed! if may_mark_confirmed?
    end

    aasm do
      state :requested, initial: true
      state :confirmed
      state :stale

      event :mark_confirmed do
        transitions from: :requested, to: :confirmed do
          guard do
            authorized && verified
          end
        end
        after do
          user.update!(email: replacement)
        end
      end

      event :mark_stale do
        transitions from: :requested, to: :stale
      end
    end

    def self.table_name_prefix
      "user_"
    end

    def send_emails
      User::EmailUpdateMailer.verification(self).deliver_now
      User::EmailUpdateMailer.authorization(self).deliver_now
    end

    private

    def non_hcb_email
      if GSuiteAccount.where(address: replacement).any?
        errors.add(:email, "must not be provided through a HCB account's Google Workspace.")
      end
    end

    def non_existing_email
      if User.where(email: replacement).any?
        errors.add(:email, "is currently in use on HCB, please use another address.")
      end
    end

  end

end
