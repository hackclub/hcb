# frozen_string_literal: true

# == Schema Information
#
# Table name: referral_programs
#
#  id                     :bigint           not null, primary key
#  name                   :string           not null
#  show_explore_hack_club :boolean          default(FALSE), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
module Referral
  class Program < ApplicationRecord
    include Hashid::Rails

    validates :name, presence: true
    validates :show_explore_hack_club, inclusion: { in: [true, false] }

    has_many :attributions, dependent: :destroy, foreign_key: :referral_program_id, inverse_of: :program
    has_many :users, -> { distinct }, through: :attributions, source: :user

  end
end
