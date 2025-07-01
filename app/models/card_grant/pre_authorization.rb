# frozen_string_literal: true

# == Schema Information
#
# Table name: card_grant_pre_authorizations
#
#  id            :bigint           not null, primary key
#  aasm_state    :string           not null
#  product_url   :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  card_grant_id :bigint           not null
#
# Indexes
#
#  index_card_grant_pre_authorizations_on_card_grant_id  (card_grant_id)
#
# Foreign Keys
#
#  fk_rails_...  (card_grant_id => card_grants.id)
#
class CardGrant
  class PreAuthorization < ApplicationRecord
    has_many_attached :screenshots
    belongs_to :card_grant

    validates :product_url, format: URI::DEFAULT_PARSER.make_regexp(%w[http https]), if: -> { product_url.present? }
    validates :product_url, presence: true, unless: :draft?

    include AASM

    aasm do
      state :draft, initial: true
      state :submitted
      state :approved

      event :mark_submitted do
        transitions from: :draft, to: :submitted
      end

      event :mark_approved do
        transitions from: :submitted, to: :approved
      end
    end

  end

end
