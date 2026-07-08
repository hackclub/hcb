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
#  external_service               :string           not null
#  failed_at                      :datetime
#  form_type                      :string
#  sent_at                        :datetime
#  signing_url                    :string
#  taxbandits_status              :string
#  taxbandits_tin_matching_status :string
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  external_id                    :string
#  legal_entity_id                :bigint           not null
#
# Indexes
#
#  index_tax_forms_on_legal_entity_id  (legal_entity_id)
#
module Tax
  class Form < ApplicationRecord
    include AASM
    include Hashid::Rails
    include PublicIdentifiable

    set_public_id_prefix :tfm
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

    after_update if: -> { taxbandits_status_previously_changed?(to: [:completed, :completed_and_tin_match_inprogress]) } do
      mark_completed!
    end

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
      raise ArgumentError, "can only send tax forms when pending" unless pending? && external_id.blank?

      case external_service
      when "taxbandits"
        send_using_taxbandits!
      when "manual"
        Rails.logger.info("[Tax::Form] NO-OP: skipping because the external service is 'manual'.")
      else
        raise ArgumentError, "Unable to send tax form using unknown external service (#{external_service})"
      end

      mark_sent!
    end

    def taxbandits_submission
      TaxbanditsService.get_submission(payee_id: legal_entity.public_id, submission_id: external_id)
    end

    def sync_with_taxbandits
      response = TaxbanditsService.get_status(payee_id: legal_entity.public_id, submission_id: external_id)

      if response.present?
        update!(
          taxbandits_status: response["FormStatus"].downcase,
          taxbandits_tin_matching_status: response["TINMatching"]&.[]("Status")&.downcase
        )
      end
    end

    private

    def send_using_taxbandits!
      response = TaxbanditsService.create_whcertificate(id: legal_entity.public_id, name: legal_entity.name)

      update!(external_service: :taxbandits, signing_url: response["Url"], external_id: response["SubmissionId"])
      sync_with_taxbandits
    end

  end
end
