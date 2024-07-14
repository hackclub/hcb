# frozen_string_literal: true

# == Schema Information
#
# Table name: user_backup_codes_lists
#
#  id                    :bigint           not null, primary key
#  codes_ciphertext      :text
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
    validates :codes, presence: true

    has_paper_trail

    before_validation do
      self.codes ||= (1..10).map { SecureRandom.alphanumeric(8) }
    end

    def use_code!(code:)
      if self.codes.include?(code)
        self.used_codes.push(code)
        self.codes.delete(code)
        regenerate_codes! if codes.empty?
        true
      else
        false
      end
    end

    def user_regenerate_codes
      regenerate_codes!
      UserMailer.backup_codes_generated(self.user).deliver_later
    end

    private

    def regenerate_codes!
      self.codes = (1..10).map { SecureRandom.alphanumeric(8) }
      self.used_codes.clear
    end

  end

end
