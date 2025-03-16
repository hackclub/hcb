# frozen_string_literal: true

# == Schema Information
#
# Table name: wires
#
#  id                        :bigint           not null, primary key
#  aasm_state                :string           not null
#  account_number_bidx       :string           not null
#  account_number_ciphertext :string           not null
#  address_city              :string
#  address_line1             :string
#  address_line2             :string
#  address_postal_code       :string
#  address_state             :string
#  amount_cents              :integer          not null
#  approved_at               :datetime
#  bic_code_bidx             :string           not null
#  bic_code_ciphertext       :string           not null
#  currency                  :string           default("USD"), not null
#  memo                      :string           not null
#  payment_for               :string           not null
#  recipient_country         :integer
#  recipient_email           :string           not null
#  recipient_information     :jsonb
#  recipient_name            :string           not null
#  return_reason             :text
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  column_id                 :text
#  event_id                  :bigint           not null
#  user_id                   :bigint           not null
#
# Indexes
#
#  index_wires_on_column_id  (column_id) UNIQUE
#  index_wires_on_event_id   (event_id)
#  index_wires_on_user_id    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (user_id => users.id)
#
class Wire < ApplicationRecord
  has_paper_trail

  include PgSearch::Model
  pg_search_scope :search_recipient, against: [:recipient_name, :recipient_email]

  has_encrypted :account_number, :bic_code
  blind_index :account_number, :bic_code

  include AASM

  include Freezeable

  include CountryEnumable
  has_country_enum(field: :recipient_country)

  belongs_to :event
  belongs_to :user

  has_one :canonical_pending_transaction

  monetize :amount_cents, as: "amount", with_model_currency: :currency

  include PublicActivity::Model
  tracked owner: proc{ |controller, record| controller&.current_user }, event_id: proc { |controller, record| record.event.id }, only: [:create]

  after_create do
    create_canonical_pending_transaction!(
      event:,
      amount_cents: -1 * usd_amount_cents,
      memo: "Wire to #{recipient_name}".strip.upcase,
      date: created_at
    )
  end

  validates_length_of :remittance_info, maximum: 140
  validates_length_of :payment_for, maximum: 140

  # IBAN & postal code formats sourced from https://column.com/docs/international-wires/country-specific-details

  IBAN_FORMATS = {
    "AD": /AD\d{2}\d{4}\d{4}[\dA-Za-z]{12}/,
    "AE": /AE\d{2}\d{3}\d{16}/,
    "AL": /AL\d{2}\d{8}[\dA-Za-z]{16}/,
    "AT": /AT\d{2}\d{5}\d{11}/,
    "AZ": /AZ\d{2}[A-Z]{4}[\dA-Za-z]{20}/,
    "BA": /BA\d{2}\d{3}\d{3}\d{8}\d{2}/,
    "BE": /BE\d{2}\d{3}\d{7}\d{2}/,
    "BG": /BG\d{2}[A-Z]{4}\d{4}\d{2}[\dA-Za-z]{8}/,
    "BH": /BH\d{2}[A-Z]{4}[\dA-Za-z]{14}/,
    "BY": /BY\d{2}[\dA-Za-z]{4}\d{4}[\dA-Za-z]{16}/,
    "CH": /CH\d{2}\d{5}[\dA-Za-z]{12}/,
    "CY": /CY\d{2}\d{3}\d{5}[\dA-Za-z]{16}/,
    "CZ": /CZ\d{2}\d{4}\d{6}\d{10}/,
    "DE": /DE\d{2}\d{8}\d{10}/,
    "DK": /DK\d{2}\d{4}\d{9}\d/,
    "EE": /EE\d{2}\d{2}\d{2}\d{11}\d/,
    "EG": /EG\d{2}\d{4}\d{4}\d{17}/,
    "ES": /ES\d{2}\d{4}\d{4}\d\d\d{10}/,
    "FI": /FI\d{2}\d{3}\d{11}/,
    "FO": /FO\d{2}\d{4}\d{9}\d/,
    "FR": /FR\d{2}\d{5}\d{5}[\dA-Za-z]{11}\d{2}/,
    "GB": /GB\d{2}[A-Z]{4}\d{6}\d{8}/,
    "GE": /GE\d{2}[A-Z]{2}\d{16}/,
    "GI": /GI\d{2}[A-Z]{4}[\dA-Za-z]{15}/,
    "GL": /GL\d{2}\d{4}\d{9}\d/,
    "GR": /GR\d{2}\d{3}\d{4}[\dA-Za-z]{16}/,
    "GT": /GT\d{2}[\dA-Za-z]{4}[\dA-Za-z]{20}/,
    "HR": /HR\d{2}\d{7}\d{10}/,
    "HU": /HU\d{2}\d{3}\d{4}\d\d{15}\d/,
    "IE": /IE\d{2}[A-Z]{4}\d{6}\d{8}/,
    "IQ": /IQ\d{2}[A-Z]{4}\d{3}\d{12}/,
    "IS": /IS\d{2}\d{4}\d{2}\d{6}\d{10}/,
    "IT": /IT\d{2}[A-Z]\d{5}\d{5}[\dA-Za-z]{12}/,
    "JM": /^\d{14}/,
    "JO": /JO\d{2}[A-Z]{4}\d{4}[\dA-Za-z]{18}/,
    "KW": /KW\d{2}[A-Z]{4}[\dA-Za-z]{22}/,
    "KZ": /KZ\d{2}\d{3}[\dA-Za-z]{13}/,
    "LB": /LB\d{2}\d{4}[\dA-Za-z]{20}/,
    "LI": /LI\d{2}\d{5}[\dA-Za-z]{12}/,
    "LT": /LT\d{2}\d{5}\d{11}/,
    "LU": /LU\d{2}\d{3}[\dA-Za-z]{13}/,
    "LV": /LV\d{2}[A-Z]{4}[\dA-Za-z]{13}/,
    "MC": /MC\d{2}\d{5}\d{5}[\dA-Za-z]{11}\d{2}/,
    "MD": /MD\d{2}[\dA-Za-z]{2}[\dA-Za-z]{18}/,
    "MT": /MT\d{2}[A-Z]{4}\d{5}[\dA-Za-z]{18}/,
    "MX": /^\d{18}/,
    "MZ": /MZ59\d{21}/,
    "NL": /NL\d{2}[A-Z]{4}\d{10}/,
    "NO": /NO\d{2}\d{4}\d{6}\d/,
    "PK": /PK\d{2}[A-Z]{4}[\dA-Za-z]{16}/,
    "PL": /PL\d{2}\d{8}\d{16}/,
    "PS": /PS\d{2}[A-Z]{4}[\dA-Za-z]{21}/,
    "PT": /PT\d{2}\d{4}\d{4}\d{11}\d{2}/,
    "QA": /QA\d{2}[A-Z]{4}[\dA-Za-z]{21}/,
    "RO": /RO\d{2}[A-Z]{4}[\dA-Za-z]{16}/,
    "RS": /RS\d{2}\d{3}\d{13}\d{2}/,
    "SA": /SA\d{2}\d{2}[\dA-Za-z]{18}/,
    "SD": /SD\d{2}\d{2}\d{12}/,
    "SE": /SE\d{2}\d{3}\d{16}\d/,
    "SI": /SI\d{2}\d{5}\d{8}\d{2}/,
    "SK": /SK\d{2}\d{4}\d{6}\d{10}/,
    "SM": /SM\d{2}[A-Z]\d{5}\d{5}[\dA-Za-z]{12}/,
    "TL": /TL\d{2}\d{3}\d{14}\d{2}/,
    "TR": /TR\d{2}\d{5}\d[\dA-Za-z]{16}/,
    "UA": /UA\d{2}\d{6}[\dA-Za-z]{19}/,
    "VA": /VA\d{2}\d{3}\d{15}/,
    "AO": /AO[\dA-Za-z]{2}\d{21}/,
    "AR": /\d{22}/,
    "BF": /BF[\dA-Za-z]{8}\d{14}/,
    "BI": /BI\d{2}\d{5}\d{5}\d{11}\d{2}/,
    "BJ": /BJ[\dA-Za-z]{8}\d{14}$/,
    "BR": /BR\d{2}\d{8}\d{5}\d{10}[A-Z][\dA-Za-z]/,
    "CF": /\d{23}/,
    "CG": /\d{23}/,
    "CI": /CI[\dA-Za-z]{8}\d{14}/,
    "CM": /(CM\d{2})?\d{23}/,
    "CR": /CR\d{2}0\d{3}\d{14}/,
    "DJ": /DJ\d{2}\d{5}\d{5}\d{11}\d{2}/,
    "DO": /DO\d{2}[A-Z]{4}\d{20}/,
    "DZ": /DZ[\dA-Za-z]{20}/,
    "GA": /\d{23}/,
    "GN": /[\dA-Za-z]{18}/,
    "GQ": /\d{23}/,
    "GW": /GW[\dA-Za-z]{8}\d{14}/,
    "IL": /IL\d{2}\d{3}\d{3}\d{13}/,
    "KG": /^\d{16}/,
    "LC": /LC\d{2}[A-Z]{4}[\dA-Za-z]{24}/,
    "LY": /LY\d{2}\d{3}\d{3}\d{15}/,
    "MA": /^\d{24}/,
    "ME": /ME\d{2}\d{3}\d{13}\d{2}/,
    "MG": /MG46\d{23}/,
    "ML": /ML[\dA-Za-z]{8}\d{14}/,
    "MK": /MK\d{2}\d{3}[\dA-Za-z]{10}\d{2}/,
    "MR": /MR\d{2}\d{5}\d{5}\d{11}\d{2}/,
    "MU": /MU\d{2}[A-Z]{4}\d{2}\d{2}\d{12}\d{3}[A-Z]{3}/,
    "NA": /\d{8,13}/,
    "NE": /NE[\dA-Za-z]{8}\d{14}$/,
    "NG": /^\d{10}/,
    "PF": /FR\d{2}\d{5}\d{5}[\dA-Za-z]{11}\d{2}/,
    "RU": /RU\d{2}\d{9}\d{5}[\dA-Za-z]{15}/,
    "SC": /SC\d{2}[A-Z]{4}\d{2}\d{2}\d{16}[A-Z]{3}/,
    "SN": /SN[\dA-Za-z]{8}\d{14}$/,
    "ST": /ST\d{2}\d{8}\d{11}\d{2}/,
    "SV": /SV\d{2}[A-Z]{4}\d{20}/,
    "TD": /\d{23}/,
    "TG": /TG[\dA-Za-z]{8}\d{14}$/,
    "TN": /TN\d{2}\d{2}\d{3}\d{13}\d{2}/,
    "VG": /VG\d{2}[A-Z]{4}\d{16}/,
    "XK": /XK\d{2}\d{4}\d{10}\d{2}/
  }.freeze

  validate do
    if IBAN_FORMATS[recipient_country.to_sym] && !account_number.match(IBAN_FORMATS[recipient_country.to_sym])
      errors.add(:account_number, "does not meet the required format for this country")
    end
  end

  POSTAL_CODE_FORMATS = {
    "US": /\A\d{5}(?:-\d{4})?\z/,
    "CN": /\A\d{6}\z/,
    "JP": /\A\d{3}-\d{4}\z/,
    "FR": /\A\d{5}\z/,
    "DE": /\A\d{5}\z/
  }.freeze

  validate do
    if POSTAL_CODE_FORMATS[recipient_country.to_sym] && !address_postal_code.match(POSTAL_CODE_FORMATS[recipient_country.to_sym])
      errors.add(:address_postal_code, "does not meet the required format for this country")
    end
  end

  validate do
    unless bic_code.match /[A-Z]{4}([A-Z]{2})[A-Z0-9]{2}([A-Z0-9]{3})?$/ # https://www.johndcook.com/blog/2024/01/29/swift/
      errors.add(:bic_code, "is not a valid SWIFT / BIC code")
    end
  end

  validate do
    if recipient_country == "US"
      errors.add(:recipient_country, "International wires can not be sent to US bank accounts, please send an ACH transfer instead.")
    end
  end

  # the SWIFT messaging system supports a very limited set of characters.
  # https://column.com/docs/international-wires/#valid-characters-permitted

  validate do
    error = "contains invalid characters; the SWIFT system only supports the English alphabet and numbers."
    regex = /[^A-Za-z0-9\-?:( ).,'+\/]/

    errors.add(:address_line1, error) if address_line1.match(regex)
    errors.add(:address_line2, error) if address_line2.present? && address_line2.match(regex)
    errors.add(:address_postal_code, error) if address_postal_code.match(regex)
    errors.add(:address_state, error) if address_state.match(regex)

    Wire.recipient_information_accessors.excluding("legal_type", "email").each do |recipient_information_accessor|
      errors.add(recipient_information_accessor, error) if recipient_information[recipient_information_accessor]&.match(regex)
    end
  end

  # see https://column.com/docs/api/#counterparty/create for valid options, under "legal_type"

  validate do
    if recipient_information[:legal_type].present? && !LEGAL_TYPE_FIELD[:options].values.include?(recipient_information[:legal_type])
      errors.add(:legal_type, "must be #{LEGAL_TYPE_FIELD[:options].keys.map(&:downcase).to_sentence(last_word_connector: ' or ')}.")
    end
  end

  # View https://github.com/hackclub/hcb/issues/9037 for context. Limited in India only, at the moment.

  RESTRICTED_PURPOSE_CODES = {
    "IN": ["P1302", "P1303", "P1304", "P1499", "P0099", "P0001", "P1011", "P1099"]
  }.freeze

  validate on: :create do
    if recipient_information[:purpose_code].present? && RESTRICTED_PURPOSE_CODES[recipient_country.to_sym]&.include?(recipient_information[:purpose_code])
      errors.add(:purpose_code, "can not be used on HCB, please use a more specific purpose code or contact us.")
    end
  end

  validate on: :create do
    if !user.admin? && usd_amount_cents < (Event.find(event.id).minimum_wire_amount_cents)
      errors.add(:amount, " must be more than or equal to #{ApplicationController.helpers.render_money event.minimum_wire_amount_cents} (USD).")
    end
  end

  aasm timestamps: true, whiny_persistence: true do
    state :pending, initial: true
    state :approved
    state :rejected
    state :deposited
    state :failed

    event :mark_approved do
      transitions from: :pending, to: :approved
    end

    event :mark_rejected do
      after do
        canonical_pending_transaction.decline!
        create_activity(key: "wire.rejected")
      end
      transitions from: [:pending, :approved], to: :rejected
    end

    event :mark_deposited do
      transitions from: :approved, to: :deposited
    end

    event :mark_failed do
      transitions from: [:deposited, :approved], to: :failed
      after do |reason = nil|
        WireMailer.with(wire: self, reason:).notify_failed.deliver_later
        create_activity(key: "wire.failed", owner: nil)
        update(return_reason: reason)
      end
    end
  end

  validates :amount_cents, numericality: { greater_than: 0, message: "must be positive!" }

  validates :recipient_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }
  normalizes :recipient_email, with: ->(recipient_email) { recipient_email.strip.downcase }

  validates_presence_of :memo, :payment_for, :recipient_name, :recipient_email

  validate on: :create do
    if usd_amount_cents > event.balance_available_v2_cents
      errors.add(:base, "You don't have enough money to send this transfer! Your balance is #{(event.balance_available_v2_cents / 100).to_money.format}. At current exchange rates, this transfer would cost #{(usd_amount_cents / 100).to_money.format} (USD).")
    end
  end

  def state
    if pending?
      :muted
    elsif rejected? || failed?
      :error
    elsif deposited?
      :success
    else
      :info
    end
  end

  def state_text
    aasm_state.humanize
  end

  alias_attribute :name, :recipient_name

  def hcb_code
    "HCB-#{TransactionGroupingEngine::Calculate::HcbCode::WIRE_CODE}-#{id}"
  end

  def admin_dropdown_description
    "#{Money.from_cents(amount_cents, currency).format} to #{recipient_name} (#{recipient_email}) from #{event.name}"
  end

  def local_hcb_code
    return nil unless persisted? # don't access local_hcb_code before saving.

    @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
  end

  def usd_amount_cents
    return -1 * local_hcb_code.amount_cents unless local_hcb_code.nil? || local_hcb_code.no_transactions?

    eu_bank = EuCentralBank.new
    eu_bank.update_rates
    eu_bank.exchange(amount_cents, currency, "USD").cents
  end

  LEGAL_TYPE_FIELD = {
    type: :select,
    key: "legal_type",
    label: "Legal status of receiving entity",
    options: {
      "Business": "business",
      "Nonprofit": "non_profit",
      "Individual": "individual",
      "Sole proprietor": "sole_proprietor"
    }
  }.freeze

  def self.information_required_for(country) # country can be null, in which case, only the general fields will be returned.
    fields = []
    case country
    when "BR"
      fields << { type: :text_field, key: "phone", label: "Phone number associated with account" }
      fields << { type: :text_field, key: "email", label: "Email address associated with account" }
      fields << LEGAL_TYPE_FIELD
      fields << { type: :text_field, key: "legal_id", label: "Legal ID of receiving entity", description: "11-digit CPF for individuals, or 14-digit CNPJ for corporations/NGO/organizations" }
      fields << { type: :text_area, key: "remittance_info", label: "Remittance information", description: "Payment purpose must be clearly identified" }
    when "BH"
      fields << { type: :text_area, key: "purpose_code", label: "Purpose code", description: "A 3-character purpose of payment code.", refer_to: "https://cbben.thomsonreuters.com/rulebook/mandating-use-purpose-codes-swift-cross-border-payments4-january-2021" }
    when "CL"
      fields << { type: :text_field, key: "legal_id", label: "Legal ID of receiving entity", description: "9-digit RUT tax ID" }
      fields << { type: :text_area, key: "purpose_code", label: "Purpose code", description: "A 5-digit purpose of payment code.", refer_to: "https://www.bcentral.cl/documents/33528/133521/Manual+de+Procedimientos+y+Formularios+de+Informaci%C3%B3n+del+CN%20CI.pdf/bcdfb774-330a-c6e1-b9fd-1b5e2c078426?t=1583165824643" }
    when "CO"
      fields << { type: :text_field, key: "phone", label: "Phone number associated with account" }
      fields << { type: :text_field, key: "email", label: "Email address associated with account" }
      fields << LEGAL_TYPE_FIELD
      fields << { type: :text_field, key: "legal_id", label: "Legal ID of receiving entity", description: "7-11 digits Cédulas for individuals, or 10-digit NIT for corporations/NGO/organizations" }
      fields << { type: :text_area, key: "purpose_code", label: "Payment purpose", description: "A clearly identifiable purpose of payment (e.g., goods, services, capital, etc.)" }
    when "DO"
      fields << { type: :text_field, key: "account_type", label: "Account type" }
      fields << LEGAL_TYPE_FIELD
      fields << { type: :text_field, key: "legal_id", label: "Legal ID of receiving entity", description: "11-digit Cedula or passport number for individuals, or 7+ digits tax ID or 9+ digits Registro Mercantil for corporations/NGO/organizations" }
    when "HN"
      fields << { type: :text_field, key: "account_type", label: "Account type" }
      fields << LEGAL_TYPE_FIELD
      fields << { type: :text_field, key: "legal_id", label: "Legal ID of receiving entity", description: "13-digit Tarjeta de Identidad for individuals, or 14-digit Registro Tributario Nacional for corporations/NGO/organizations" }
      fields << { type: :text_area, key: "remittance_info", label: "Remittance information", description: "For payments from corporations/organizations to individuals, include a detailed purpose of payment (especially for salaries)" }
    when "KZ"
      fields << LEGAL_TYPE_FIELD
      fields << { type: :text_field, key: "legal_id", label: "Legal ID of receiving entity", description: "12-digit Business Identification Number (BIN) or Individual Identification Number (IIN)" }
      fields << { type: :text_area, key: "remittance_info", label: "Remittance information", description: "Payment purpose must be clearly identified" }
      fields << { type: :text_area, key: "purpose_code", label: "Payment purpose", description: "A 10-character EKNP purpose code" }
    when "MD"
      fields << { type: :text_field, key: "phone", label: "Phone number associated with account" }
    when "MY"
      fields << LEGAL_TYPE_FIELD
      fields << { type: :text_area, key: "purpose_code", label: "Purpose code", description: "A 5-digit purpose of payment code.", refer_to: "https://connect-content.us.hsbc.com/hsbc_pcm/onetime/17_july_my_pop_codes.pdf" }
    when "PK"
      fields << LEGAL_TYPE_FIELD
      fields << { type: :text_field, key: "legal_id", label: "Legal ID of receiving entity", description: "Should be prepended with CNIC, SNIC, Passport, or NTN depending on the ID type." }
      fields << { type: :text_area, key: "remittance_info", label: "Remittance information", description: "Relationship between remitter and beneficiary must be clearly identified" }
      fields << { type: :text_area, key: "purpose_code", label: "Purpose code", description: "A 4-digit purpose of payment code.", refer_to: "https://www.sbp.org.pk/fe_returns/cod5.pdf" }
    when "PY"
      fields << LEGAL_TYPE_FIELD
      fields << { type: :text_field, key: "legal_id", label: "Legal ID of receiving entity", description: "Cedula de Identidad for individuals, or RUC for corporations" }
    when "AM"
      fields << LEGAL_TYPE_FIELD
      fields << { type: :text_area, key: "remittance_info", label: "Remittance information", description: "Payment purpose must be clearly identified" }
    when "AR"
      fields << { type: :text_field, key: "email", label: "Email address associated with account" }
      fields << { type: :text_field, key: "legal_id", label: "Legal ID of receiving entity", description: "11-digit CUIL for individuals, or 11-digit CUIT for corporations" }
    when "AE"
      fields << { type: :text_area, key: "remittance_info", label: "Remittance information", description: "Payment purpose must be clearly identified" }
      fields << { type: :text_area, key: "purpose_code", label: "Purpose code", description: "A 3-character purpose of payment code.", refer_to: "https://www.centralbank.ae/media/ipaifsll/bop-purposeofpaymentcodestable-en-18092017.pdf" }
    when "AL"
      fields << { type: :text_area, key: "remittance_info", label: "Remittance information", description: "For utility payments: client name, bill month, and contract number of the subscriber. For tax payments: FDP (payment order document generated by Tax Office system). For fee payments: NIPT (tax ID)." }
    when "AU"
      fields << { type: :text_field, key: "local_bank_code", label: "Local bank code", description: "6-digit BSB code" }
    when "AZ"
      fields << { type: :text_field, key: "legal_id", label: "Legal ID of receiving entity", description: "10-digit TIN/VOEN" }
      fields << { type: :text_field, key: "local_bank_code", label: "Local bank code", description: "6-digit BIK code" }
      fields << { type: :text_area, key: "remittance_info", label: "Remittance information", description: "Payment purpose must be clearly identified, especially for charitable purposes to avoid income tax" }
    when "BA"
      fields << { type: :text_area, key: "remittance_info", label: "Remittance information", description: "If the beneficiary belongs to a government organization, Budget Organization Code, Profit Type (6-digit) and Citation Number (municipality, 3-digit) are required" }
    when "BG"
      fields << { type: :text_area, key: "remittance_info", label: "Remittance information", description: "For tax payments: 6-digit payment type defined by the Ministry of Finance and local regulation, and one of the following: BULSTAT (Bulgarian Identification Tax Number, 6-digit for corporations), EGN (Bulgarian citizen ID), PNF (foreign citizen ID), or IZL (name of legal entity or individual)" }
    when "BD"
      fields << { type: :text_field, key: "phone", label: "Phone number associated with account" }
      fields << { type: :text_field, key: "local_bank_code", label: "Local bank code", description: "9-digit bank routing code" }
    when "BY"
      fields << { type: :text_field, key: "local_bank_code", label: "Local bank code", description: "3-9 digits MFO bank code" }
      fields << { type: :text_field, key: "legal_id", label: "Legal ID of receiving entity", description: "Tax ID" }
      fields << { type: :text_area, key: "remittance_info", label: "Remittance information", description: "Payment purpose must be clearly identified" }
    when "BZ"
      fields << { type: :text_field, key: "local_bank_code", label: "Local bank code", description: "5-digit branch code" }
    when "BS"
      fields << { type: :text_area, key: "remittance_info", label: "Remittance information", description: "Transit Number is required if the beneficiary bank is RBC Bahamas" }
    when "CA"
      fields << { type: :text_field, key: "local_bank_code", label: "Local bank code", description: "9-digit Canadian Payments Association Routing Number" }
    when "CM"
      fields << { type: :text_field, key: "phone", label: "Phone number associated with account" }
    when "CN"
      fields << { type: :text_area, key: "purpose_code", label: "Purpose code", description: "CAP (Capital Account), GDS (Goods Trade), SRV (Service Trade), CAC (Current Account), or FTF (Bank to Bank Funds Transfer)" }
    when "CR"
      fields << { type: :text_field, key: "legal_id", label: "Legal ID of receiving entity", description: "9-12 digits Cedula Juridica" }
      fields << { type: :text_field, key: "local_account_number", label: "Local account number", description: "17-digit Cuenta Cliente" }
    when "DZ"
      fields << { type: :text_area, key: "remittance_info", label: "Remittance information", description: "For invoices: reason for the invoice (e.g., invoice for health services). Otherwise provide a general reason for payment." }
    when "GY"
      fields << { type: :text_area, key: "remittance_info", label: "Remittance information", description: "8-digit Transit Code is mandatory (format: TRANSIT CODE: XXXXXXXX). Funds paid to the Guyana Revenue Authority requires a reference (format: YYMMDD/RRRRRRRRRRRR), which can be obtained from the Guyana Revenue Authority." }
    when "ID"
      fields << { type: :text_field, key: "phone", label: "Phone number associated with account" }
    when "IN"
      fields << LEGAL_TYPE_FIELD
      fields << { type: :text_field, key: "phone", label: "Phone number associated with account" }
      fields << { type: :text_field, key: "local_bank_code", label: "Local bank code", description: "11-character IFSC codes" }
      fields << { type: :text_area, key: "purpose_code", label: "Purpose code", description: "A 5-character purpose of payment code, beginning with 'P'.", refer_to: "https://rbidocs.rbi.org.in/rdocs/notification/PDFs/ASAP840212FL.pdf" }
    when "JO"
      fields << { type: :text_area, key: "remittance_info", label: "Remittance information", description: "Payment purpose must be clearly identified" }
      fields << { type: :text_area, key: "purpose_code", label: "Purpose code", description: "A 4-digit purpose of payment code.", refer_to: "https://www.cbj.gov.jo/EchoBusv3.0/SystemAssets/PDFs/1%D8%A7%D9%84%D8%BA%D8%B1%D8%B6%20%D9%85%D9%86%20%D8%A7%D9%84%D8%AA%D8%AD%D9%88%D9%8A%D9%84%D8%A7%D8%AA%200%D8%A7%D9%84%D9%85%D8%A7%D9%84%D9%8A%D8%A9-20191029.pdf" }
    when "KG"
      fields << { type: :text_field, key: "local_bank_code", label: "Local bank code", description: "6-digit BIK code" }
      fields << { type: :text_area, key: "purpose_code", label: "Purpose code", description: "A 8-digit purpose of payment code" }
    when "KR"
      fields << { type: :text_field, key: "phone", label: "Phone number associated with account" }
      fields << LEGAL_TYPE_FIELD
      fields << { type: :text_field, key: "legal_id", label: "Legal ID of receiving entity", description: "10-digit Business Registration Number (for corporations)" }
      fields << { type: :text_area, key: "purpose_code", label: "Purpose code", description: "A 5-digit purpose of payment code.", refer_to: "https://www.jpmorgan.com/directdoc/list-of-payment-purpose-code-kr.pdf" }
    when "MU"
      fields << { type: :text_area, key: "remittance_info", label: "Remittance information", description: "Payment purpose must be clearly identified" }
    when "MM"
      fields << { type: :text_area, key: "purpose_code", label: "Purpose code", description: "A 4-digit ITRS code" }
    when "MX"
      fields << { type: :text_field, key: "local_bank_code", label: "Local bank code", description: "Nostro Account Number" }
    when "MZ"
      fields << { type: :text_field, key: "legal_id", label: "Legal ID of receiving entity", description: "9-digit NUIT: Taxpayer Single ID Number" }
    when "NE"
      fields << { type: :text_field, key: "phone", label: "Phone number associated with account" }
    when "NP"
      fields << { type: :text_area, key: "remittance_info", label: "Remittance information", description: "9-digit Permanent Account Number (PAN) is required for (i) payments related to social media content and software development by individuals or corporations or equivalent and (ii) payments related to any consultancy services would apply to individual only." }
    when "NZ"
      fields << { type: :text_field, key: "local_bank_code", label: "Local bank code", description: "6-digit NZ Clearing Code" }
    when "PE"
      fields << LEGAL_TYPE_FIELD
      fields << { type: :text_field, key: "legal_id", label: "Legal ID of receiving entity", description: "11-digit RUC number for corporations, or 8-digit DNI for individuals" }
    when "TG"
      fields << { type: :text_field, key: "phone", label: "Phone number associated with account" }
    when "TW"
      fields << { type: :text_field, key: "phone", label: "Phone number associated with account" }
    when "UA"
      fields << { type: :text_field, key: "legal_type", label: "Type of entity" }
      fields << { type: :text_field, key: "legal_id", label: "Legal ID of receiving entity", description: "10-digit tax ID for individuals, or 8-digit tax ID for corporations/NGO/organizations" }
    when "UG"
      fields << { type: :text_field, key: "legal_id", label: "Legal ID of receiving entity", description: "13-digit PRN tax ID" }
    when "SA"
      fields << { type: :text_area, key: "remittance_info", label: "Remittance information", description: "Payment purpose must be clearly identified" }
    when "ZM"
      fields << { type: :text_field, key: "local_bank_code", label: "Local bank code", description: "6-digit branch code" }
    when "ZA"
      fields << { type: :text_area, key: "remittance_info", label: "Remittance information", description: "For tax payments, include unique 19 character Payment Reference Number(PRN) (e.g., /PRN/xxxxxxxxxxxxxxxxxxx)" }
    end
    return fields
  end

  def self.recipient_information_accessors
    fields = []
    Event.countries_for_select.each do |country|
      fields += self.information_required_for(country[0])
    end
    fields.collect{ |field| field[:key] }.uniq
  end

  store :recipient_information, accessors: self.recipient_information_accessors

  def send_wire!
    return unless may_mark_approved?

    account_number_id = (event.column_account_number || event.create_column_account_number)&.column_id

    column_counterparty = ColumnService.post("/counterparties", {
      idempotency_key: self.id.to_s,
      routing_number_type: "bic",
      routing_number: bic_code,
      account_number:,
      wire: {
        beneficiary_name: recipient_name,
        beneficiary_email: recipient_email,
        beneficiary_address: {
          line_1: address_line1,
          line_2: address_line2,
          city: address_city,
          state: address_state,
          postal_code: address_postal_code,
          country_code: recipient_country
        },
        beneficiary_legal_id: recipient_information[:legal_id],
        beneficiary_type: recipient_information[:legal_type],
        local_bank_code: recipient_information[:local_bank_code],
        local_account_number: recipient_information[:local_account_number],
        account_type: recipient_information[:account_type]
      }.compact_blank
    }.compact_blank)

    column_wire_transfer = ColumnService.post("/transfers/international-wire", {
      idempotency_key: self.id.to_s,
      amount: amount_cents,
      currency_code: currency,
      counterparty_id: column_counterparty["id"],
      description: payment_for,
      account_number_id:,
      message_to_beneficiary_bank: "please contact with the beneficiary",
      remittance_info: {
        general_info: recipient_information[:remittance_info]
      },
      purpose_code: recipient_information[:purpose_code]
    }.compact_blank)

    self.column_id = column_wire_transfer["id"]
    mark_approved
    save!
  end

end
