# frozen_string_literal: true

# == Schema Information
#
# Table name: referral_links
#
#  id                  :bigint           not null, primary key
#  name                :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  referral_program_id :bigint           not null
#
# Indexes
#
#  index_referral_links_on_referral_program_id  (referral_program_id)
#
# Foreign Keys
#
#  fk_rails_...  (referral_program_id => referral_programs.id)
#
module Referral
  class Link < ApplicationRecord
    include Hashid::Rails

    validates :name, presence: true

    belongs_to :program, class_name: "Referral::Program", foreign_key: "referral_program_id", inverse_of: :links

  end
end
