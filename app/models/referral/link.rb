# frozen_string_literal: true

# == Schema Information
#
# Table name: referral_links
#
#  id         :bigint           not null, primary key
#  slug       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  creator_id :bigint           not null
#
# Indexes
#
#  index_referral_links_on_creator_id  (creator_id)
#  index_referral_links_on_slug        (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#
module Referral
  class Link < ApplicationRecord
    include Hashid::Rails

    belongs_to :creator, class_name: "User"

    def value
      slug || hashid
    end
  end
end
