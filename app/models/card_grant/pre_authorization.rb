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
    has_many_attached :screenshots, dependent: :destroy
    belongs_to :card_grant

    include Turbo::Broadcastable

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

    def status_badge_type
      return :muted if draft?
      return :pending if submitted?
      return :success if approved?

      :muted
    end

    def analyze!
      conn = Faraday.new url: "https://api.openai.com" do |f|
        f.request :json
        f.request :authorization, "Bearer", -> { Credentials.fetch(:OPENAI_API_KEY) }
        f.response :raise_error
        f.response :json
      end

      response = conn.post("/v1/responses", {
                             model: "gpt-4.1",
                             input: [
                               {
                                 role: "system",
                                 content: [
                                   { type: "input_text",
                                     text: "You are an AI tool that receives a product URL and screenshots of a product / shopping cart, as well as a purpose for the purchase. Your task is to analyze the product and return a JSON object with the following keys: `product_name`, `product_description`, `product_price`, and `valid_purchase`. Valid purchase is the most important: it helps us determine if a purchase is an acceptable use of these funds. Make sure not to include backticks in the JSON response."
                 }
                                 ],
                               }, { role: "user", content: [

                                 { type: "input_text", text: "Product URL: #{product_url}" },
                                 screenshots.map { |screenshot|
                                   {
                                     type: "input_image",
                                     image_url:
                                                                         screenshot.service_url,
                                   }
                                 }
                               ]
},

                             ],

                           })


      mark_approved! if screenshots.attached? && product_url.present?

      broadcast_refresh_to self
    end

  end

end
