# frozen_string_literal: true

# == Schema Information
#
# Table name: referral_programs
#
#  id                   :bigint           not null, primary key
#  background_image_url :string
#  login_body_text      :text
#  login_header_text    :string
#  login_text_color     :string
#  name                 :string           not null
#  redirect_to          :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  creator_id           :bigint           not null
#
# Indexes
#
#  index_referral_programs_on_creator_id  (creator_id)
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#
module Referral
  class Program < ApplicationRecord
    include Hashid::Rails

    validates :name, presence: true
    validates :redirect_to, format: URI::DEFAULT_PARSER.make_regexp(%w[http https]), if: -> { redirect_to.present? }

    belongs_to :creator, class_name: "User"

    has_many :attributions, dependent: :destroy, foreign_key: :referral_program_id, inverse_of: :program
    has_many :users, -> { distinct }, through: :attributions, source: :user
    has_many :logins, foreign_key: :referral_program_id, class_name: "Login", inverse_of: :referral_program
    has_many :links, class_name: "Referral::Link", inverse_of: :program

    def background_image_css
      background_image_url.present? ? "url('#{background_image_url}')" : nil
    end

    def new_users
      attributions.joins(:user)
                  .where("EXTRACT(EPOCH FROM (referral_attributions.created_at - users.created_at)) < 60*60")
                  .map(&:user)
                  .uniq
    end

  end
end
