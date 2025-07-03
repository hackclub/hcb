# frozen_string_literal: true

# == Schema Information
#
# Table name: card_grant_pre_authorizations
#
#  id                            :bigint           not null, primary key
#  aasm_state                    :string           not null
#  extracted_fraud_rating        :integer
#  extracted_merchant_name       :string
#  extracted_product_description :text
#  extracted_product_name        :string
#  extracted_product_price_cents :integer
#  extracted_total_price_cents   :integer
#  extracted_valid_purchase      :boolean
#  extracted_validity_reasoning  :text
#  product_url                   :string
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  card_grant_id                 :bigint           not null
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
        after do
          ::CardGrant::PreAuthorization::AnalyzeJob.perform_later(pre_authorization: self)
        end
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
        f.response :json
      end

      prompt = <<~PROMPT
        You are a helpful assistant that extracts information from a provided product URL and shopping cart screenshots. Once you've extracted the necessary information, you must decide whether the purchase is a valid use of funds based on a given purpose. You must respond in the following JSON format:

        product_name // the name of the product, if available
        product_description // a short description of the product, if available
        product_price_cents // the price of the product, if available, in cents (e.g., 1500 for $15.00)
        total_price_cents // the total price, in cents, including any surcharges or fees added at checkout. this is potentially different from the product price.
        merchant_name // the name of the merchant, if available

        validity_reasoning // a short explanation of why the purchase is valid or not, based on the purpose provided. This should be a concise sentence explaining the reasoning behind the decision.
        valid_purchase // a boolean value indicating whether the purchase is a valid use of funds based on the purpose provided. This should be true or false.
        fraud_rating // a number between 1 and 10, where 1 is very likely to be valid and 10 is very likely to be fraudulent.
      PROMPT

      response = conn.post("/v1/responses", {
                             model: "gpt-4.1",
                             input: [
                               {
                                 role: "system",
                                 content: [
                                   {
                                     type: "input_text",
                                     text: prompt
                                   }
                                 ],
                               },
                               {
                                 role: "user",
                                 content: [
                                   {
                                     type: "input_text",
                                     text: "Product URL: #{product_url}"
                                   },
                                   screenshots.map { |screenshot|
                                     {
                                       type: "input_image",
                                       image_url: Rails.application.routes.url_helpers.url_for(screenshot),
                                     }
                                   }
                                 ].flatten
                               },

                             ],

                           })

      raw_response = response.body.dig("output", 0, "content", 0, "text")
      json_response = begin
        JSON.parse(raw_response)
      rescue JSON::ParserError
        {}
      end

      params = ActionController::Parameters.new(json_response.transform_keys { |key| "extracted_#{key}".to_sym }).permit(
        :extracted_product_name,
        :extracted_product_description,
        :extracted_product_price_cents,
        :extracted_total_price_cents,
        :extracted_merchant_name,
        :extracted_validity_reasoning,
        :extracted_valid_purchase,
        :extracted_fraud_rating
      )

      update(**params)

      mark_approved! if screenshots.attached? && product_url.present?

      broadcast_refresh_to self
    end

  end

end
