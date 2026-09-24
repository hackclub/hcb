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
    # Passed to OpenAI as a strict structured output schema, which guarantees the
    # model responds with exactly these keys as valid JSON — no prose, no code
    # fences, no top-level array.
    ANALYSIS_RESPONSE_FORMAT = {
      type: "json_schema",
      name: "purchase_analysis",
      strict: true,
      schema: {
        type: "object",
        additionalProperties: false,
        properties: {
          product_name: {
            type: ["string", "null"],
            description: "The name of the product. If the cart contains several products, summarize them. Null if unavailable."
          },
          product_description: {
            type: ["string", "null"],
            description: "A short description of the product. Null if unavailable."
          },
          product_price_cents: {
            type: ["integer", "null"],
            description: "The price of the product, in cents (e.g., 1500 for $15.00). Null if unavailable."
          },
          total_price_cents: {
            type: ["integer", "null"],
            description: "The total price, in cents, including any surcharges or fees added at checkout. This is potentially different from the product price. Null if unavailable."
          },
          merchant_name: {
            type: ["string", "null"],
            description: "The name of the merchant. Null if unavailable."
          },
          validity_reasoning: {
            type: "string",
            description: "A concise sentence explaining why the purchase is or isn't a valid use of funds, based on the purpose provided."
          },
          valid_purchase: {
            type: "boolean",
            description: "Whether the purchase is a valid use of funds based on the purpose provided."
          },
          fraud_rating: {
            type: "integer",
            minimum: 1,
            maximum: 10,
            description: "A number between 1 and 10, where 1 is very likely to be valid and 10 is very likely to be fraudulent."
          }
        },
        required: [
          :product_name,
          :product_description,
          :product_price_cents,
          :total_price_cents,
          :merchant_name,
          :validity_reasoning,
          :valid_purchase,
          :fraud_rating
        ]
      }
    }.freeze

    has_many_attached :screenshots, dependent: :destroy
    validates :screenshots, size: { less_than_or_equal_to: 20.megabytes }, if: -> { attachment_changes["screenshots"].present? }

    belongs_to :card_grant
    has_one :event, through: :card_grant
    has_one :card_grant_setting, through: :card_grant
    has_one :user, through: :card_grant

    include Turbo::Broadcastable

    validates :product_url, format: URI::DEFAULT_PARSER.make_regexp(%w[http https]), if: -> { product_url.present? }
    validates :product_url, presence: true, unless: :draft?

    include AASM

    aasm do
      state :draft, initial: true
      state :submitted
      state :approved
      state :fraudulent
      state :rejected

      event :mark_submitted do
        transitions from: :draft, to: :submitted
        after_commit do
          ::CardGrant::PreAuthorization::AnalyzeJob.perform_later(pre_authorization: self)
        end
      end

      event :mark_approved do
        transitions from: [:submitted, :fraudulent], to: :approved do
          guard do
            screenshots.attached? && product_url.present?
          end
        end
      end

      event :mark_fraudulent do
        transitions from: :submitted, to: :fraudulent
        after do
          PreAuthorizationMailer.with(pre_authorization: self).notify_fraudulent.deliver_later
        end
      end

      event :mark_rejected do
        transitions from: :fraudulent, to: :rejected
        after do |rejected_by|
          card_grant.cancel!(rejected_by)
        end
      end
    end

    def status_badge_type(organizer: false)
      return :muted if draft?
      return :pending if submitted?
      return :success if approved? || (fraudulent? && authorized? && !organizer)
      return :error if (fraudulent? && authorized? && organizer) || (fraudulent? && unauthorized?)
      return :error if rejected?

      :muted
    end

    def status_text(organizer: false)
      return "Draft" if draft?
      return "Under review" if submitted?
      return "Approved" if approved? || (fraudulent? && authorized? && !organizer)
      return "Flagged as fraudulent" if (fraudulent? && authorized? && organizer) || (fraudulent? && unauthorized?)

      return "Rejected" if rejected?

      aasm_state.humanize
    end

    def analyze!
      conn = Faraday.new url: "https://api.openai.com" do |c|
        c.request :json
        c.request :authorization, "Bearer", -> { Credentials.fetch(:OPENAI, :PRE_AUTHORIZATION) }
        c.response :json
        c.response :raise_error
      end

      prompt = <<~PROMPT
        You are a helpful assistant that extracts information from a provided product URL and shopping cart screenshots. Once you've extracted the necessary information, you must decide whether the purchase is a valid use of funds based on a set of user-facing instructions.

        If the cart contains several products, describe the cart as a whole rather than picking out a single line item.

        Please make sure that both the product URL and screenshots are in line with the instructions provided to the user. If there isn't enough information, or these 3 fields are not all aligned, you should reject the purchase as fraudulent. #{"The purpose of the grant is '#{card_grant.purpose}'." if card_grant.purpose.present?} Here are the instructions provided to the user:

        #{card_grant.instructions.presence || "No specific instructions were provided."}
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
                                     text: "The user provided the following URL: #{product_url}.",
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
                             text: {
                               format: ANALYSIS_RESPONSE_FORMAT
                             },

                           })

      raw_response = response.body["output"]
                             &.find { |item| item["type"] == "message" }
                             &.dig("content", 0, "text")
      raw_params = begin
        JSON.parse(raw_response.to_s).transform_keys { |key| "extracted_#{key}".to_sym }
      rescue JSON::ParserError
        {}
      end

      params = ActionController::Parameters.new(raw_params).permit(
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

      if params[:extracted_valid_purchase]
        mark_approved!
      else
        mark_fraudulent!
      end

      broadcast_refresh_to self
    rescue Faraday::Error => e
      # If OpenAI rejects the image as invalid, mark as fraudulent
      if e.response_body&.include?("does not represent a valid image")
        mark_fraudulent!
        broadcast_refresh_to self
        return
      end

      # Modify the original exception to append the response body to the message
      # so these are easier to debug
      raise(e.exception(<<~MSG))
        #{e.message}
        \tresponse_body: #{e.response_body.inspect}
      MSG
    end

    def unauthorized?
      draft? || submitted? || rejected? || (card_grant_setting.block_suspected_fraud? && fraudulent?)
    end

    def authorized?
      approved? || (!card_grant_setting.block_suspected_fraud? && fraudulent?)
    end

  end

end
