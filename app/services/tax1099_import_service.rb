# frozen_string_literal: true

# Imports a single W-9, W-8BEN or W-8BEN-E that was collected through Tax1099
# into TaxBandits, from
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

  W9 = "W9"
  W8BEN = "W8BEN"
  W8BENE = "W8BENE"
  FORM_TYPES = [W9, W8BEN, W8BENE].freeze
  W8_FORM_TYPES = [W8BEN, W8BENE].freeze

  TIN_TYPES = %w[SSN EIN FTIN].freeze

  # A W-9 is only ever filed with a US TIN, and these W-8s are imported with the
  # payee's foreign TIN.
  TIN_TYPES_BY_FORM_TYPE = {
    W9     => %w[SSN EIN],
    W8BEN  => %w[FTIN],
    W8BENE => %w[FTIN],
  }.freeze

  # TaxBandits' Ch3Status values for a W-8BEN-E. Tax1099's export doesn't carry
  # it, so an admin always picks it from the signed form.
  CH3_STATUSES = %w[
    CORPORATION PARTNERSHIP DISREGARDED_ENTITY SIMPLE_TRUST GRANTOR_TRUST COMPLEX_TRUST ESTATE
    TAX_EXEMPT_ORGANIZATION PRIVATE_FOUNDATION INTERNATIONAL_ORGANIZATION CENTRAL_BANK_OF_ISSUE
    FOREIGN_GOVERNMENT_CONTROLLED_ENTITY FOREIGN_GOVERNMENT_INTEGRAL_PART
  ].freeze

  # Enforces at most one live tax1099 form per TIN; see the migration that adds it.
  UNIQUE_TIN_INDEX = "index_tax_forms_unique_live_tax1099_tin_hash"

  # :required is true, or the form types the field is required for. :only_for,
  # when present, is the form types the field applies to at all; the page hides
  # it for the rest. :hint, when present, is shown as a tooltip on the label.
  FIELDS = [
    { key: :form_type, label: "Form Type", required: true },
    { key: :first_name, label: "Payee First Name (or business name)", required: true },
    { key: :middle_name, label: "Payee Middle Name", required: false },
    { key: :last_name, label: "Payee Last Name", required: false },
    { key: :suffix, label: "Payee Suffix", required: false },
    # A W-9 always has a TIN. A W-8 may not: its payee can instead tick "FTIN
    # not legally required"; see #validate_w8_tin!.
    { key: :tin, label: "TIN (EIN/SSN/FTIN)", required: [W9] },
    { key: :tin_type, label: "TIN Type", required: [W9] },
    { key: :ftin_not_legally_required, label: "FTIN not legally required (box ticked on the form)", required: false, only_for: W8_FORM_TYPES },
    { key: :federal_tax_classification, label: "Federal Tax Classification", required: [W9], only_for: [W9] },
    {
      key: :ch3_status, label: "Chapter 3 Status", required: [W8BENE], only_for: [W8BENE],
      hint: "On the W-8BEN-E, copy the one box ticked in Part I, line 4 (\"Chapter 3 Status (entity type)\"). " \
            "Ignore line 4's \"hybrid entity\" yes/no question, and don't use line 5: that's the Chapter 4 (FATCA) status."
    },
    { key: :address1, label: "Address", required: true },
    { key: :city, label: "City", required: true },
    { key: :state, label: "State / Province", required: [W9] },
    { key: :zip_code, label: "Zip / Postal Code", required: [W9] },
    # The country of residence (or, for a W-8BEN-E, of organization). Ignored for
    # a W-9, which is always US.
    { key: :country, label: "Country (2-letter code)", required: W8_FORM_TYPES, only_for: W8_FORM_TYPES },
    {
      key: :signer_name, label: "Signer Name", required: W8_FORM_TYPES, only_for: W8_FORM_TYPES,
      hint: "The name printed in the signature section at the bottom of the form " \
            "(\"Print name of signer\"). On a W-8BEN this is usually the payee themselves."
    },
    { key: :email, label: "Email Address", required: true },
    { key: :completed_on, label: "Form Completed Date", required: true },
  ].freeze

  Result = Struct.new(:form, :legal_entity, keyword_init: true)

  # data                  — the reviewed row, keyed by FIELDS' :key values.
  # pdf                   — the uploaded signed form PDF (anything responding to #read).
  # legal_entity          — the LegalEntity an admin picked when the payee
  #                         already had business entities to choose from.
  # new_legal_entity      — true when the admin chose to create a new business
  #                         entity instead. One of the two is required whenever
  #                         .legal_entity_candidates isn't empty.
  # pdf_url_builder       — called with the store token, returns the URL to hand
  #                         to TaxBandits. Injected because URL generation needs
  #                         the request's host.
  def initialize(data:, pdf:, pdf_url_builder:, legal_entity: nil, new_legal_entity: false)
    @data = data.symbolize_keys
    @pdf = pdf
    @pdf_url_builder = pdf_url_builder
    @legal_entity = legal_entity
    @new_legal_entity = new_legal_entity
  end

  def run
    validate!

    if (duplicate = duplicate_tax1099_form)
      raise DuplicateError, duplicate
    end

    # Checked up front because once TaxBandits has accepted the submission
    # there is no taking it back, so the form must be certain to land somewhere.
    validate_legal_entity_choice!

    # Staged before anything is created so that a rejected upload (too large,
    # not a PDF) doesn't leave an orphaned user, legal entity, or form behind.
    pdf_token = Tax::W9PdfStore.store(@pdf)

    # The user, legal entity, and completed form all exist before TaxBandits is
    # contacted, so that once it has accepted the submission there is nothing
    # left that could fail and strand it. The TaxBandits call happens inside the
    # transaction so that a rejected submission rolls all of them back.
    #
    # complete_form! is what sets tin_hash, which is what
    # index_tax_forms_unique_live_tax1099_tin_hash keys on. Doing it before the
    # submission is what makes double imports impossible: a second import of the
    # same TIN racing this one blocks on that index until this transaction ends,
    # then fails there, before it has sent anything to TaxBandits.
    submitted = false
    form, legal_entity = begin
      ActiveRecord::Base.transaction do
        legal_entity = find_or_create_legal_entity!
        form = Tax::Form.create!(external_service: :taxbandits, source: :tax1099, legal_entity:)
        complete_form!(form)

        response = submit!(form, pdf_token)
        submitted = true
        form.update!(external_id: response["SubmissionId"])

        [form, legal_entity]
      end
    rescue => e
      # Nothing will ever fetch this PDF now, so don't leave it sitting out its
      # TTL in the cache. Once TaxBandits has accepted the submission it may
      # still re-read the PDF within the grace window, so leave it alone then.
      Tax::W9PdfStore.discard(pdf_token) unless submitted

      # Lost the race to a concurrent import of the same TIN. That import has
      # committed by now (the index made this one wait for it), so it can be
      # reported like any other duplicate.
      if e.is_a?(ActiveRecord::RecordNotUnique) && e.message.include?(UNIQUE_TIN_INDEX) && (duplicate = duplicate_tax1099_form)
        raise DuplicateError, duplicate
      end

      raise
    end

    legal_entity.refresh_pending_contractors_payments!

    Result.new(form:, legal_entity:)
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

  # Keys for every live Tax1099 import, so the page can hide CSV rows that an
  # earlier session already imported. Built only from what an import already
  # stores on the form, and never from the TIN: the browser can't compute
  # tin_hash, and an unkeyed fingerprint of a TIN could be brute-forced.
  #
  # This is a convenience filter, not the duplicate check. A row that slips
  # through (say, its email was edited during review) is still rejected by
  # tin_hash on import. Must stay in step with rowKey() in
  # tax1099_import_controller.js.
  def self.imported_row_keys
    Tax::Form.tax1099.not_discarded.where.not(completed_at: nil).includes(legal_entity: :users).flat_map do |form|
      kind = form.entity_person? ? "person" : "business"

      form.legal_entity.users.map do |user|
        row_key(email: user.email, completed_on: form.completed_at.to_date.iso8601, kind:, zip_code: form.address_postal_code)
      end
    end.uniq
  end

  def self.row_key(email:, completed_on:, kind:, zip_code:)
    [
      email.to_s.strip.downcase,
      completed_on,
      kind,
      normalize_postal_code(zip_code),
    ].join("|")
  end

  # Mirrors Tax::Form#entity_type_from, so an imported form gets the same entity
  # type a TaxBandits sync of the same form would give it.
  # Letters and digits only, uppercased, so "sw1a 1aa" and "SW1A 1AA" agree. A
  # ZIP+4 is cut to its ZIP so "11385" and "11385-1234" agree too.
  def self.normalize_postal_code(postal_code)
    normalized = postal_code.to_s.gsub(/[^0-9A-Za-z]/, "").upcase
    normalized.match?(/\A\d{9}\z/) ? normalized[0, 5] : normalized
  end

  def self.entity_type_for(form_type:, tin_type:, federal_tax_classification:)
    if form_type == W8BEN
      :person
    elsif form_type == W8BENE
      :business
    elsif tin_type == "SSN"
      :person
    elsif federal_tax_classification.to_s.include?("Corporation")
      :corporation
    else
      :business
    end
  end

  private

  def validate!
    unless FORM_TYPES.include?(form_type)
      raise ValidationError, "form type must be one of: #{FORM_TYPES.join(", ")}"
    end

    missing = FIELDS.select { |field| required?(field) && @data[field[:key]].blank? }
    raise ValidationError, "missing required field(s): #{missing.map { _1[:label] }.join(", ")}" if missing.any?

    validate_w8_tin! if W8_FORM_TYPES.include?(form_type)

    tin_types = TIN_TYPES_BY_FORM_TYPE.fetch(form_type)
    if tin? && !tin_types.include?(@data[:tin_type])
      raise ValidationError, "TIN type for a #{form_type} must be one of: #{tin_types.join(", ")}"
    end

    if form_type == W9 && !FEDERAL_TAX_CLASSIFICATIONS.include?(@data[:federal_tax_classification])
      raise ValidationError, "federal tax classification must be one of: #{FEDERAL_TAX_CLASSIFICATIONS.join(", ")}"
    end

    if form_type == W8BENE && !CH3_STATUSES.include?(@data[:ch3_status])
      raise ValidationError, "chapter 3 status must be one of: #{CH3_STATUSES.join(", ")}"
    end

    if W8_FORM_TYPES.include?(form_type) && !country.match?(/\A[A-Z]{2}\z/)
      raise ValidationError, "country must be a 2-letter country code"
    end

    raise ValidationError, "a signed form PDF is required" if @pdf.blank?

    raise ValidationError, "form completed date must be a date (YYYY-MM-DD)" if completed_on.nil?
    raise ValidationError, "form completed date can't be in the future" if completed_on > Time.zone.today
  end

  def required?(field)
    field[:required] == true || (field[:required].is_a?(Array) && field[:required].include?(form_type))
  end

  def form_type
    @data[:form_type].to_s
  end

  # A W-9 payee is always in the US. For a W-8 it's the country of residence
  # (or organization), which is also the country that issued its foreign TIN.
  def country
    form_type == W9 ? "US" : @data[:country].to_s.strip.upcase
  end

  # A W-8 either gives a foreign TIN or says, with the box on the form, that the
  # payee's country doesn't require one. Exactly one, so the admin is copying
  # what the signed form says rather than HCB assuming it from a blank TIN.
  def validate_w8_tin!
    if !tin? && !ftin_not_legally_required?
      raise ValidationError, "enter the foreign TIN, or tick \"FTIN not legally required\" if the form does"
    elsif tin? && ftin_not_legally_required?
      raise ValidationError, "a form with a foreign TIN can't also say an FTIN isn't legally required"
    end
  end

  def tin?
    @data[:tin].present?
  end

  def ftin_not_legally_required?
    ActiveModel::Type::Boolean.new.cast(@data[:ftin_not_legally_required]) || false
  end

  def foreign_tin?
    tin? && @data[:tin_type] == "FTIN"
  end

  # When the payee actually completed the form in Tax1099, not when it was
  # imported. LegalEntity#latest_completed_tax_form and friends rank forms by
  # completed_at, so stamping an old form with the import time would let it
  # outrank a newer form the payee has since completed through TaxBandits.
  def completed_on
    return @completed_on if defined?(@completed_on)

    @completed_on = begin
      Date.iso8601(@data[:completed_on].to_s)
    rescue Date::Error
      nil
    end
  end

  # A personal form always goes on the personal entity, and a payee with no
  # business entity yet gets a new one. Anything else is ambiguous, and the
  # admin has to settle it before the row is submitted.
  def validate_legal_entity_choice!
    return if entity_type == :person

    candidates = self.class.legal_entity_candidates(email: @data[:email], entity_type:)

    if @legal_entity
      # Guard against a stale or hand-edited id pointing at somebody else's
      # entity: the form would otherwise attach a payee's TIN to a stranger.
      unless candidates.include?(@legal_entity)
        raise ValidationError, "the selected legal entity is not one of #{@data[:email]}'s business legal entities"
      end
    elsif candidates.any? && !@new_legal_entity
      raise ValidationError, "#{@data[:email]} already has business legal entities; pick one, or choose to create a new one"
    end
  end

  def entity_type
    @entity_type ||= self.class.entity_type_for(
      form_type:,
      tin_type: @data[:tin_type],
      federal_tax_classification: @data[:federal_tax_classification]
    )
  end

  # A foreign TIN is only unique within the country that issued it, so it's
  # namespaced by the country of residence, the same way Tax::Form#identify_tin
  # namespaces one from a TaxBandits sync.
  def tin_hash
    @tin_hash ||= Tax::IdentificationNumber::Hasher.hash_tin(
      @data[:tin],
      tin_type: tin_namespace,
      country: foreign_tin? ? country : "US"
    )
  end

  # The TIN space (individual, entity or foreign) the fingerprint and the form's
  # tin_type use, as opposed to @data[:tin_type] (SSN, EIN or FTIN).
  # nil without a TIN, same as a TIN-less W-8 synced from TaxBandits.
  def tin_namespace
    return nil unless tin?

    Tax::IdentificationNumber::Hasher.tin_type_for(entity_type:, foreign: foreign_tin?)
  end

  # A TIN-less W-8 has no fingerprint to check, and find_by(tin_hash: nil) would
  # match every other TIN-less import.
  def duplicate_tax1099_form
    return nil if tin_hash.nil?

    Tax::Form.tax1099.not_discarded.find_by(tin_hash:)
  end

  # Populates what Tax::Form#import_taxbandits_data would otherwise have derived
  # from a TaxBandits sync, and marks the form completed directly: the recipient
  # never visits TaxBandits themselves (create_from_data submits the completed
  # form data on their behalf), so these forms are already complete the moment
  # TaxBandits accepts them and nothing will ever import their data afterwards.
  # Runs before the submission, inside the same transaction; see #run.
  def complete_form!(form)
    form.update!(
      form_type:,
      entity_type:,
      tin_type: tin_namespace,
      tin_hash:,
      address_line1: @data[:address1],
      address_city: @data[:city],
      address_state: @data[:state].presence,
      address_postal_code: @data[:zip_code].presence,
      address_country: country,
      aasm_state: "completed",
      completed_at: completed_on.in_time_zone
    )
  end

  def build_payload(form, pdf_url)
    {
      "FormType"      => form_type,
      "IsTinMatching" => false,
      "PayeeRef"      => form.public_id,
      "PdfUrl"        => pdf_url,
    }.merge(
      case form_type
      when W9 then { "FormW9" => w9_payload }
      when W8BEN then { "FormW8Ben" => w8ben_payload }
      when W8BENE then { "FormW8BENE" => w8bene_payload }
      end
    )
  end

  def w9_payload
    {
      "FirstNm"                  => @data[:first_name],
      "Line1Nm"                  => full_name,
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
  end

  # Tax1099's export has a single country, so it is used for citizenship as well
  # as residence. TaxBandits requires the signer's name on a W-8, which an admin
  # copies from the signed PDF.
  def w8ben_payload
    {
      "NmOfIndividual"           => full_name,
      "FirstNm"                  => @data[:first_name],
      "MiddleNm"                 => @data[:middle_name],
      "LastNm"                   => @data[:last_name],
      "Suffix"                   => @data[:suffix],
      "CitizenOfCountry"         => country,
      "ForeignTIN"               => @data[:tin].presence,
      "IsFTINNotLegallyRequired" => ftin_not_legally_required?,
      "PermanentAddress"         => w8_address,
      "MailingAddress"           => w8_address,
      "Signature"                => { "SignerNm" => @data[:signer_name] }
    }
  end

  def w8bene_payload
    {
      "Part1"  => {
        "NmOfOrganization"         => @data[:first_name],
        "CountryOfOrganization"    => country,
        "Ch3Status"                => @data[:ch3_status],
        "ForeignTIN"               => @data[:tin].presence,
        "IsFTINNotLegallyRequired" => ftin_not_legally_required?,
        "PermanentAdd"             => w8_address,
        "MailAdd"                  => w8_address
      },
      # The certification the signer made by signing the PDF (line 30), dated
      # when the form was completed.
      "Part30" => {
        "IsCapacityToSign" => true,
        "SignerNm"         => @data[:signer_name],
        # The format of TaxBandits' sample request; it documents no other.
        "SignDate"         => completed_on.strftime("%Y-%m-%dT00:00:00")
      }
    }
  end

  # TaxBandits' W-8BEN sample names the region ProvinceOrStateNm while its field
  # reference (and the W-8BEN-E) call it State, so both are sent.
  def w8_address
    {
      "Address1"          => @data[:address1],
      "City"              => @data[:city],
      "State"             => @data[:state].presence,
      "ProvinceOrStateNm" => @data[:state].presence,
      "Country"           => country,
      "PostalCd"          => @data[:zip_code].presence
    }
  end

  def full_name
    [@data[:first_name], @data[:middle_name], @data[:last_name], @data[:suffix]].compact_blank.join(" ")
  end

  # Finds the legal entity the form belongs on by email, same as the console
  # script this replaces: SSNs go on the user's personal legal entity, EINs go
  # on the business entity the admin picked or, failing that, a new one. The
  # choice was already validated by #validate_legal_entity_choice!.
  def find_or_create_legal_entity!
    user = User.find_or_create_by!(email: @data[:email])

    if entity_type == :person
      user.personal_legal_entity
    else
      @legal_entity || LegalEntity.create!(name: @data[:first_name], entity_type:, users: [user])
    end
  end

  def submit!(form, pdf_token)
    TaxbanditsService.create_from_data(build_payload(form, @pdf_url_builder.call(pdf_token)))
  rescue => e
    raise SubmissionError, "TaxBandits rejected the submission: #{scrub(e.message)}", cause: nil
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
