# frozen_string_literal: true

# == Schema Information
#
# Table name: user_backup_codes_lists
#
#  id                    :bigint           not null, primary key
#  codes_ciphertext      :text
#  deleted_at            :datetime
#  last_generated_at     :datetime
#  used_codes_ciphertext :text
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  user_id               :bigint           not null
#
# Indexes
#
#  index_user_backup_codes_lists_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class User
  class BackupCodesList < ApplicationRecord
    acts_as_paranoid
    belongs_to :user, inverse_of: :backup_codes_list
    has_encrypted :codes, type: :array
    has_encrypted :used_codes, type: :array

    has_paper_trail

    before_create do
      self.codes = (1..10).map { SecureRandom.alphanumeric(8) }
      self.last_generated_at = Time.now
    end

    def use_code!(code:, session:)
      if self.codes.include?(code)
        ActiveRecord::Base.transaction do
          self.used_codes.push(code)
          self.codes.delete(code)
          UserMailer.backup_code_used(user:, session:).deliver_now
          save!
        end
        # we don't regenerate their codes if they use all of them currently - this should be a user action
        true
      else
        false
      end
    end

    def user_regenerate_codes(session:)
      regenerate_codes!
      UserMailer.backup_codes_generated(user:, session:).deliver_later
    end

    private

    def regenerate_codes!
      ActiveRecord::Base.transaction do
        self.codes = (1..10).map { SecureRandom.alphanumeric(8) }
        self.used_codes.clear
        self.last_generated_at = Time.now
        save!
      end
    end

  end

end
