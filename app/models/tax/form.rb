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
#  entity_type                    :string
#  external_service               :string           not null
#  failed_at                      :datetime
#  form_type                      :string
#  sent_at                        :datetime
#  signing_url                    :string
#  taxbandits_status              :string
#  taxbandits_tin_matching_status :string
#  tin_hash                       :string
#  tin_type                       :string
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  external_id                    :string
#  legal_entity_id                :bigint           not null
#
# Indexes
#
#  index_tax_forms_on_legal_entity_id  (legal_entity_id)
#  index_tax_forms_on_tin_hash         (tin_hash)
#
module Tax
  class Form < ApplicationRecord
    include AASM
    include Hashid::Rails
    include PublicIdentifiable

    class ImportError < StandardError; end

    set_public_id_prefix :tfm
    acts_as_paranoid
    has_paper_trail

    belongs_to :legal_entity

    enum :form_type, { W8BEN: "W8BEN", W9: "W9", W8BENE: "W8BENE", W8ECI: "W8ECI", W8IMY: "W8IMY", W8EXP: "W8EXP" }
    enum :external_service, { manual: "manual", taxbandits: "taxbandits" }, prefix: :sent_with
    enum :entity_type, { person: "person", business: "business" }, prefix: :entity

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

    scope :not_discarded, -> { where.not(aasm_state: :discarded) }

    validate :tin_hash_cannot_change, on: :update

    after_update if: -> {
      taxbandits_status_previously_changed?(to: :completed) ||
        taxbandits_status_previously_changed?(to: :completed_and_tin_match_inprogress)
    } do
      mark_completed! if may_mark_completed?
    end

    after_update if: -> { tin_hash_previously_changed?(from: nil) } do
      # Locked: a legal entity's TIN can never change once set, and two forms
      # completing concurrently would otherwise both see a nil hash and race.
      #
      # A form whose entity type disagrees with the legal entity's is a filing
      # mistake (e.g. a W-8BEN-E against a personal LE); it must not claim the
      # entity's TIN identity. Left un-adopted, entity_type_mismatched_tax_form
      # flags it and the payee is prompted to discard it.
      legal_entity.with_lock do
        if legal_entity.tin_hash.nil? && entity_type == legal_entity.entity_type
          legal_entity.update!(tin_hash:)
        end
      end
    end

    aasm timestamps: true do
      state :pending, initial: true
      state :sent # Request sent to TaxBandits, not necessarily email sent
      state :completed
      state :failed # Failed to create document / send email
      state :discarded

      event :mark_sent do
        transitions from: :pending, to: :sent
      end

      event :mark_completed do
        transitions from: :sent, to: :completed
        after do
          import_taxbandits_data if sent_with_taxbandits?

          legal_entity.payments.each(&:on_legal_entity_payable) if legal_entity.payable?
          legal_entity.refresh_contractor_onboarding!
        end
      end

      event :mark_failed do
        transitions from: :sent, to: :failed
      end

      event :mark_discarded do
        transitions from: [:pending, :sent, :completed], to: :discarded
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

    def sync_with_taxbandits
      # A manually entered form has no certificate at TaxBandits to sync against.
      return unless sent_with_taxbandits?

      response = TaxbanditsService.get_status(public_id)

      if response.present?
        update!(
          taxbandits_status: response["FormStatus"].downcase,
          taxbandits_tin_matching_status: response["TINMatching"]&.[]("Status")&.downcase
        )
      end
    end

    # Only the last four digits, and only ever shown to the payee themselves.
    # Read from TaxBandits' List endpoint (which masks the TIN for us) so that HCB
    # never stores even a partial TIN.
    #
    # A manually entered form has no TaxBandits certificate to read from, so it has
    # no maskable TIN. Callers must handle nil.
    def masked_tin
      return nil unless sent_with_taxbandits?
      return @masked_tin if defined?(@masked_tin)

      @masked_tin = begin
        entry = TaxbanditsService.get_list_entry(public_id)
        tin = entry&.[]("TIN")

        if tin.present? && tin.count("Xx") >= 3
          # TaxBandits usually masks the TIN for us; trust it if it's actually masked
          tin
        else
          # Otherwise (an unmasked TIN, or only an FTIN is available), mask it ourselves
          raw = tin.presence || entry&.[]("FTIN")

          if raw.blank?
            nil
          elsif raw.length <= 4
            "X" * raw.length
          else
            raw.slice(-4, 4).rjust(raw.length, "X")
          end
        end
      end
    end

    private

    # WhCertificate/Get returns the payee's full, unmasked TIN. Nothing outside
    # import_taxbandits_data may call it, and what it derives (entity type, TIN
    # type, address) is persisted so that no page render ever needs it again.
    def remote_taxbandits_submission
      TaxbanditsService.get_submission(public_id)
    end

    def tin_hash_cannot_change
      if tin_hash_changed? && tin_hash_was.present?
        errors.add(:tin_hash, "cannot change once set")
      end
    end

    def send_using_taxbandits!
      response = TaxbanditsService.create_whcertificate(id: public_id, name: legal_entity.name)

      update!(external_service: :taxbandits, signing_url: response["Url"], external_id: response["SubmissionId"])
      sync_with_taxbandits
    end

    def import_taxbandits_data
      submission = remote_taxbandits_submission
      return if submission.nil?

      submission_form_type = submission["FormType"]
      form_data = submission.dig(TaxbanditsService::TAXBANDITS_FORM_DATA_KEYS[submission_form_type], "FormData")

      return if form_data.blank?

      # These different address field names come from different
      # object shapes depending on the type of tax form
      address = case submission_form_type
                when "FormW9"
                  form_data["Address"]
                when "FormW8BEN", "FormW8ECI"
                  form_data["MailAdd"]
                when "FormW8BENE", "FormW8IMY", "FormW8EXP"
                  form_data.dig("Part1", "MailAdd")
                end

      return if address.blank?

      us_tin, foreign_tin = case submission_form_type
                            when "FormW9"
                              [form_data["TIN"], nil]
                            when "FormW8BEN"
                              [form_data["USTIN"], form_data["ForeignTIN"]]
                            when "FormW8ECI"
                              [form_data["TIN"], form_data["ForeignTIN"]]
                            when "FormW8BENE", "FormW8IMY", "FormW8EXP"
                              [form_data.dig("Part1", "USTIN"), form_data.dig("Part1", "ForeignTIN")]
                            end

      entity_type = entity_type_from(submission_form_type, form_data)
      tin, tin_type, country = identify_tin(us_tin, foreign_tin, entity_type, submission_form_type, form_data)

      # Only fingerprint when we have both a TIN and the space it belongs to. A
      # foreign filer whose country of residence we can't determine is left with a
      # nil hash (un-deduped, same as a TIN-less W-8) rather than fingerprinted into
      # a guessed bucket, which would risk merging two unrelated taxpayers.
      tin_hash = if tin.present? && country.present?
                   Tax::IdentificationNumber::Hasher.hash_tin(tin, tin_type:, country:)
                 end

      update!(
        form_type: submission_form_type[4..],
        entity_type:,
        tin_type:,
        tin_hash:,
        address_line1: address["Address1"],
        address_line2: address["Address2"],
        address_city: address["City"],
        address_state: address["State"] || address["ProvinceOrStateNm"],
        address_postal_code: address["PostalCd"] || address["ZipCd"],
        address_country: address["Country"]
      )
    rescue => e
      # The raw submission, form_data, and TIN are all in scope here, so a raised
      # error's message/backtrace/cause could carry an SSN. Sever the cause and
      # re-raise something that names only the form (never the PII), so nothing
      # sensitive can reach Rails logs or AppSignal. cause: nil mirrors the same
      # defense in Tax::IdentificationNumber::Hasher#hash_tin.
      raise ImportError, "failed to import TaxBandits data for #{public_id} (#{e.class})", cause: nil
    end

    def entity_type_from(submission_form_type, form_data)
      case submission_form_type
      when "FormW9"
        form_data["TINType"] == "SSN" ? :person : :business
      when "FormW8BEN"
        :person
      when "FormW8ECI"
        form_data["EntityType"] == "INDIVIDUAL" ? :person : :business
      when "FormW8BENE", "FormW8IMY", "FormW8EXP"
        :business
      else
        raise ArgumentError, "unknown tax form type #{submission_form_type}"
      end
    end

    # A US TIN is preferred over a foreign one: it is what the IRS reports against,
    # and it is the only identifier that lets us recognise the same taxpayer across
    # a W-9 and a W-8. The namespace has to describe the *TIN*, not the form, or the
    # same person filing both would fingerprint to two different taxpayers.
    def identify_tin(us_tin, foreign_tin, entity_type, submission_form_type, form_data)
      if us_tin.present?
        [us_tin, Tax::IdentificationNumber::Hasher.tin_type_for(entity_type:), "US"]
      else
        # A foreign TIN is only unique within its issuing country, so the country of
        # tax residence is part of the taxpayer's identity here. It must be the
        # permanent-residence country, never the mailing address, which can change
        # between filings and would split one taxpayer across two fingerprints.
        [foreign_tin,
         Tax::IdentificationNumber::Hasher.tin_type_for(entity_type:, foreign: true),
         residence_country_for(submission_form_type, form_data)]
      end
    end

    # The country whose tax authority issued the foreign TIN. Read from the W-8's
    # permanent-residence / country-of-organization fields, falling back through the
    # plausible TaxBandits key names. Returns nil (rather than a guess) when none is
    # present, so the caller skips fingerprinting instead of bucketing by mail.
    def residence_country_for(submission_form_type, form_data)
      candidates = case submission_form_type
                   when "FormW8BEN", "FormW8ECI"
                     [form_data.dig("PermanentAddress", "Country"),
                      form_data.dig("PermanentAdd", "Country"),
                      form_data["CitizenOfCountry"],
                      form_data["Country"]]
                   when "FormW8BENE", "FormW8IMY", "FormW8EXP"
                     [form_data.dig("Part1", "PermanentAdd", "Country"),
                      form_data.dig("Part1", "PermanentAddress", "Country"),
                      form_data.dig("Part1", "CountryOfOrganization"),
                      form_data.dig("Part1", "Country")]
                   else
                     []
                   end

      candidates.map { |value| value.to_s.strip.presence }.compact.first
    end

  end
end
