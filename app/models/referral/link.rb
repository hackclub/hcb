# frozen_string_literal: true

# == Schema Information
#
# Table name: referral_links
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  slug       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  creator_id :bigint           not null
#  program_id :bigint           not null
#
# Indexes
#
#  index_referral_links_on_creator_id  (creator_id)
#  index_referral_links_on_program_id  (program_id)
#  index_referral_links_on_slug        (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (program_id => referral_programs.id)
#
module Referral
  class Link < ApplicationRecord
    include Hashid::Rails

    after_create_commit :set_default_slug!
    validates :slug, uniqueness: true

    belongs_to :program, class_name: "Referral::Program"
    belongs_to :creator, class_name: "User"

    has_many :attributions, dependent: :destroy, foreign_key: :referral_link_id, inverse_of: :link
    has_many :users, -> { distinct }, through: :attributions, source: :user
    has_many :logins, foreign_key: :referral_link_id, class_name: "Login", inverse_of: :referral_link

    def new_teenagers
      attributions.joins(:user)
                  .where("EXTRACT(EPOCH FROM (referral_attributions.created_at - users.created_at)) < 60*60")
                  .where("users.joined_as_teenager = true")
                  .map(&:user)
                  .uniq
    end

    private

    def set_default_slug!
      update!(slug: self.hashid) unless self.slug.present?
    end

  end
end
