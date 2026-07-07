# frozen_string_literal: true

# == Schema Information
#
# Table name: tax_forms
#
#  id                             :bigint           not null, primary key
#  aasm_state                     :string           not null
#  address_city                   :string
#  address_country                :string
#  address_line1                  :string
#  address_line2                  :string
#  address_postal_code            :string
#  address_state                  :string
#  completed_at                   :datetime
#  deleted_at                     :datetime
#  document_url                   :string
#  external_service               :string           not null
#  failed_at                      :datetime
#  form_type                      :string
#  sent_at                        :datetime
#  signing_url                    :string
#  taxbandits_status              :string
#  taxbandits_tin_matching_status :string
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  legal_entity_id                :bigint           not null
#
# Indexes
#
#  index_tax_forms_on_legal_entity_id  (legal_entity_id)
#
module Tax
  class Form < ApplicationRecord
    self.ignored_columns += ["external_id"]

    include AASM
    include Hashid::Rails
    acts_as_paranoid
    has_paper_trail

    belongs_to :legal_entity

    enum :form_type, { W8BEN: "W8BEN", W9: "W9", W8BENE: "W8BENE", W8ECI: "W8ECI", W8IMY: "W8IMY", W8EXP: "W8EXP" }
    enum :external_service, { manual: "manual", taxbandits: "taxbandits" }, prefix: :sent_with

    # https://developer.taxbandits.com/docs/whcertificate/status/
    enum :taxbandits_status, %w[
      url_generated
      order_created
      scheduled
      sent
      opened
      completed
      awaiting_tin_certificate
      completed_and_tin_match_inprogress
      invalid
      bounced
      order_not_created
    ].index_with(&:itself), prefix: :taxbandits

    enum :taxbandits_tin_matching_status, %w[
      order_created
      success
      failed
    ].index_with(&:itself), prefix: :taxbandits_tin_match

    aasm timestamps: true do
      state :pending, initial: true
      state :sent # Request sent to TaxBandits, not necessarily email sent
      state :completed
      state :failed # Failed to create document / send email

      event :mark_sent do
        transitions from: :pending, to: :sent
      end

      event :mark_completed do
        transitions from: :sent, to: :completed
        after do
          legal_entity.payments.each(&:on_legal_entity_payable) if legal_entity.payable?
        end
      end

      event :mark_failed do
        transitions from: :sent, to: :failed
      end
    end

    def send!
      raise ArgumentError, "can only send tax forms when pending" unless pending?

      send_using_taxbandits! unless sent_with_manual?

      mark_sent!
    end

    def taxbandits_submission
      taxbandits_client.get("WhCertificate/Get?PayeeRef=#{hashid}").body
    rescue Faraday::ResourceNotFound, Faraday::BadRequestError
      # TaxBandits will respond with 400 or 404 if the submission is not yet complete
      nil
    end

    def sync_with_taxbandits
      mark_completed! if taxbandits_submission.present?
    end

    private

    def taxbandits_client
      @taxbandits_client || begin
        Faraday.new(url: Rails.env.development? ? "https://testapi.taxbandits.com/v1.7.3/" : "https://api.taxbandits.com/v1.7.3/") do |faraday|
          faraday.response :json
          faraday.response :raise_error
          faraday.adapter Faraday.default_adapter
          faraday.headers["Authorization"] = "Bearer #{taxbandits_access_token}"
          faraday.headers["Content-Type"] = "application/json"
        end
      end
    end

    def taxbandits_access_token
      Rails.cache.fetch("taxbandits_access_token", expires_in: 50.minutes) do
        payload = {
          iss: Credentials.fetch(:TAXBANDITS, :CLIENT_ID),
          sub: Credentials.fetch(:TAXBANDITS, :CLIENT_ID),
          aud: Credentials.fetch(:TAXBANDITS, :USER_TOKEN),
          iat: Time.now.to_i
        }

        signature = JWT.encode(payload, Credentials.fetch(:TAXBANDITS, :CLIENT_SECRET), "HS256")

        oauth_response = Faraday.new(url: Rails.env.development? ? "https://testoauth.expressauth.net" : "https://oauth.expressauth.net") do |conn|
          conn.response :json
          conn.headers["Authentication"] = signature
          conn.adapter Faraday.default_adapter
        end.get("/v2/tbsauth")

        oauth_response.body["AccessToken"]
      end
    end

    def send_using_taxbandits!
      response = taxbandits_client.post("WhCertificate/RequestByUrl") do |req|
        req.body = {
          "Recipient" => {
            "PayeeRef"      => hashid,
            "Name"          => legal_entity.name,
            "IsTINMatching" => true
          },
          "CustomizationId": Credentials.fetch(:TAXBANDITS, :CUSTOMIZATION_ID)
        }.to_json
      end

      update!(external_service: :taxbandits, signing_url: response.body["Url"])
    end

  end
end
