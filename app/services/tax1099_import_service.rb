# frozen_string_literal: true

# Imports a single W-9 that was collected through Tax1099 into TaxBandits, from
# data an admin has reviewed in the browser (see Admin::Tax1099ImportsController
# and the tax1099_import Stimulus controller, which parse the Tax1099 CSV export
# client-side so it is never uploaded anywhere).
#
# One row in, one Tax::Form out. TaxBandits accepts the completed form data on
# the payee's behalf, so unlike a form HCB sends for signature there is nothing
# to wait for: the form is marked completed here rather than by a later webhook.
class Tax1099ImportService
  class Error < StandardError; end

  # Raised when a not-discarded tax1099 form already exists for this TIN.
  class DuplicateError < Error
    attr_reader :existing_form

    def initialize(existing_form)
      @existing_form = existing_form
      super("a tax1099 form for this TIN already exists (#{existing_form.public_id})")
    end

  end

  class ValidationError < Error; end

  # Raised when TaxBandits rejects the submission. Its message is scrubbed of the
  # submitted TIN before it is built; see #submission_error.
  class SubmissionError < Error; end

  # Tax1099's export has no column we can trust for this, so it is never
  # prefilled from the CSV and an admin always picks it by hand.
  FEDERAL_TAX_CLASSIFICATIONS = [
    "Individual", "Sole Proprietor", "Single Member LLC Not Elected", "Single Member LLC Elected",
    "C Corporation", "S Corporation", "Partnership", "Trust or Estate", "LLC C Corporation",
    "LLC S Corporation", "LLC Partnership", "Others"
  ].freeze

  TIN_TYPES = %w[SSN EIN].freeze

  FIELDS = [
    { key: :first_name, label: "Payee First Name (or business name)", required: true },
    { key: :middle_name, label: "Payee Middle Name", required: false },
    { key: :last_name, label: "Payee Last Name", required: false },
    { key: :suffix, label: "Payee Suffix", required: false },
    { key: :tin, label: "TIN (EIN/SSN)", required: true },
    { key: :tin_type, label: "TIN Type", required: true },
    { key: :federal_tax_classification, label: "Federal Tax Classification", required: true },
    { key: :address1, label: "Address", required: true },
    { key: :city, label: "City", required: true },
    { key: :state, label: "State", required: true },
    { key: :zip_code, label: "Zip Code", required: true },
    { key: :email, label: "Email Address", required: true },
  ].freeze

  Result = Struct.new(:form, :legal_entity, :needs_manual_review, keyword_init: true) do
    def needs_manual_review? = !!needs_manual_review
  end

  # data                  — the reviewed row, keyed by FIELDS' :key values.
  # pdf                   — the uploaded W-9 PDF (anything responding to #read).
  # legal_entity          — the LegalEntity an admin picked when the payee
  #                         already had more than one business entity to choose
  #                         from; nil leaves the form for manual assignment.
  # pdf_url_builder       — called with the store token, returns the URL to hand
  #                         to TaxBandits. Injected because URL generation needs
  #                         the request's host.
  def initialize(data:, pdf:, pdf_url_builder:, legal_entity: nil)
    @data = data.symbolize_keys
    @pdf = pdf
    @pdf_url_builder = pdf_url_builder
    @legal_entity = legal_entity
  end

  def run
    validate!

    if (duplicate = duplicate_tax1099_form)
      raise DuplicateError, duplicate
    end

    # Staged before the form exists so that a rejected upload (too large, not a
    # PDF) doesn't leave an orphaned Tax::Form behind.
    pdf_token = Tax::W9PdfStore.store(@pdf)

    form = Tax::Form.create!(external_service: :taxbandits, source: :tax1099)

    begin
      response = TaxbanditsService.create_from_data(build_payload(form, @pdf_url_builder.call(pdf_token)))
    rescue => e
      # Nothing will ever fetch this PDF now, so don't leave it sitting out its
      # TTL in the cache.
      Tax::W9PdfStore.discard(pdf_token)
      form.destroy!
      raise SubmissionError, "TaxBandits rejected the submission: #{scrub(e.message)}", cause: nil
    end

    form.update!(external_id: response["SubmissionId"])

    assigned_legal_entity = assign_legal_entity!(form)

    # The recipient never visits TaxBandits themselves (create_from_data already
    # submitted the completed form data on their behalf), so nothing will ever
    # call Tax::Form#import_taxbandits_data for these forms. Set what it would
    # have derived directly, and mark the form complete now rather than leaving
    # it stuck pending forever.
    complete_form!(form)
    form.legal_entity&.refresh_pending_contractors_payments!

    Result.new(form:, legal_entity: assigned_legal_entity, needs_manual_review: assigned_legal_entity.nil?)
  end

  # The business legal entities an admin has to choose between before a row can
  # be imported. Empty when the choice is unambiguous: a personal form always
  # goes on the user's personal legal entity, and a payee with no business
  # entity yet gets a new one. Called on its own (without a TIN or a PDF) so the
  # page can ask the question before anything sensitive is submitted.
  def self.legal_entity_candidates(email:, entity_type:)
    return [] if entity_type.to_s == "person"

    user = User.find_by(email:)
    return [] if user.nil?

    user.legal_entities.where.not(entity_type: :person).to_a
  end

  def self.entity_type_for(tin_type:, federal_tax_classification:)
    if tin_type == "SSN"
      :person
    elsif federal_tax_classification.to_s.include?("Corporation")
      :corporation
    else
      :business
    end
  end

  private

  def validate!
    missing = FIELDS.select { |field| field[:required] && @data[field[:key]].blank? }
    raise ValidationError, "missing required field(s): #{missing.map { _1[:label] }.join(", ")}" if missing.any?

    unless TIN_TYPES.include?(@data[:tin_type])
      raise ValidationError, "TIN type must be one of: #{TIN_TYPES.join(", ")}"
    end

    unless FEDERAL_TAX_CLASSIFICATIONS.include?(@data[:federal_tax_classification])
      raise ValidationError, "federal tax classification must be one of: #{FEDERAL_TAX_CLASSIFICATIONS.join(", ")}"
    end

    raise ValidationError, "a W-9 PDF is required" if @pdf.blank?
  end

  def entity_type
    @entity_type ||= self.class.entity_type_for(
      tin_type: @data[:tin_type],
      federal_tax_classification: @data[:federal_tax_classification]
    )
  end

  def tin_hash
    @tin_hash ||= Tax::IdentificationNumber::Hasher.hash_tin(
      @data[:tin],
      tin_type: Tax::IdentificationNumber::Hasher.tin_type_for(entity_type:),
      country: "US"
    )
  end

  def duplicate_tax1099_form
    Tax::Form.tax1099.not_discarded.find_by(tin_hash:)
  end

  # Populates what Tax::Form#import_taxbandits_data would otherwise have derived
  # from a TaxBandits sync, and marks the form completed directly: these forms
  # are already complete the moment TaxBandits accepts them, and nothing will
  # ever sync them afterwards.
  def complete_form!(form)
    form.update!(
      form_type: :W9,
      entity_type:,
      tin_type: Tax::IdentificationNumber::Hasher.tin_type_for(entity_type:),
      tin_hash:,
      address_line1: @data[:address1],
      address_city: @data[:city],
      address_state: @data[:state],
      address_postal_code: @data[:zip_code],
      address_country: "US",
      aasm_state: "completed",
      completed_at: Time.current
    )
  end

  def build_payload(form, pdf_url)
    {
      "FormType"      => "W9",
      "IsTinMatching" => false,
      "PayeeRef"      => form.public_id,
      "PdfUrl"        => pdf_url,
      "FormW9"        => {
        "FirstNm"                  => @data[:first_name],
        "Line1Nm"                  => [@data[:first_name], @data[:middle_name], @data[:last_name], @data[:suffix]].compact_blank.join(" "),
        "MiddleNm"                 => @data[:middle_name],
        "LastNm"                   => @data[:last_name],
        "Suffix"                   => @data[:suffix],
        "TINType"                  => @data[:tin_type],
        "TIN"                      => @data[:tin],
        "Address"                  => {
          "Address1" => @data[:address1],
          "City"     => @data[:city],
          "State"    => @data[:state],
          "ZipCd"    => @data[:zip_code]
        },
        "FederalTaxClassification" => @data[:federal_tax_classification]
      }
    }
  end

  # Associates the form with a legal entity by email, same as the console script
  # this replaces: SSNs go on the user's personal legal entity, EINs create (or
  # reuse) a business/corporation legal entity. Returns nil when the payee
  # already had several business legal entities and the admin declined to pick
  # one, leaving the form for manual assignment.
  def assign_legal_entity!(form)
    user = User.find_or_create_by!(email: @data[:email])

    legal_entity =
      if entity_type == :person
        user.personal_legal_entity
      elsif @legal_entity
        # Guard against a stale or hand-edited id pointing at somebody else's
        # entity: the form would otherwise attach a payee's TIN to a stranger.
        unless user.legal_entities.exists?(id: @legal_entity.id)
          raise ValidationError, "the selected legal entity does not belong to #{user.email}"
        end

        @legal_entity
      elsif user.legal_entities.where.not(entity_type: :person).none?
        LegalEntity.create!(name: @data[:first_name], entity_type:, users: [user])
      end

    form.update!(legal_entity:) if legal_entity

    legal_entity
  end

  # Faraday's raise_error middleware puts the whole response body in the error
  # message, and a TaxBandits validation error echoes back the field it rejected
  # — which for a W-9 can be the TIN itself. Anything that reaches Rails' logs,
  # AppSignal, or the admin's browser from here has to have the TIN removed
  # first, and the original exception severed (cause: nil at the raise site) so
  # its unscrubbed message can't ride along. Same defense as
  # Tax::Form#import_taxbandits_data.
  def scrub(message)
    tin = @data[:tin].to_s
    variants = [tin, tin.delete("-")].map(&:presence).compact.uniq

    variants.reduce(message.to_s.truncate(1000)) { |text, variant| text.gsub(variant, "[FILTERED]") }
  end

end
