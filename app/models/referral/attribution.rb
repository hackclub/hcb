# frozen_string_literal: true

# == Schema Information
#
# Table name: referral_attributions
#
#  id                  :bigint           not null, primary key
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  referral_program_id :bigint           not null
#  user_id             :bigint           not null
#
# Indexes
#
#  index_referral_attributions_on_referral_program_id  (referral_program_id)
#  index_referral_attributions_on_user_id              (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (referral_program_id => referral_programs.id)
#  fk_rails_...  (user_id => users.id)
#
module Referral
  class Attribution < ApplicationRecord
    belongs_to :program, class_name: "Referral::Program", foreign_key: "referral_program_id", inverse_of: :attributions
    belongs_to :user # Referee (person being referred)

  end
end
