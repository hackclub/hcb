# frozen_string_literal: true

module HasWiseRecipient
  extend ActiveSupport::Concern

  included do
    include CountryEnumable
    has_country_enum(field: :recipient_country)

    before_validation(:normalize_wise_recipient_id)
    validates(:wise_recipient_id, format: { with: WISE_RECIPIENT_ID_FORMAT, message: "is not a valid Wise recipient ID" }, allow_nil: true)

    validate do
      if POSTAL_CODE_FORMATS[recipient_country&.to_sym] && !address_postal_code.match(POSTAL_CODE_FORMATS[recipient_country.to_sym])
        errors.add(:address_postal_code, "does not meet the required format for this country")
      end
    end

    validate do
      unless currency.in?(AVAILABLE_CURRENCIES)
        errors.add(:currency, "is not supported for Wise transfers")
      end
    end

    # Ops can set this to finish a transfer that was already in flight (e.g. a
    # reimbursement approved before its currency or rail became unsupported).
    attr_accessor :allow_unsupported_recipient

    # Block *new* recipients on rails/currencies Wise can't currently pay out
    # to (e.g. Interac, Duitnow, CNY). This only runs on create, so existing
    # transfers and payout methods stay valid and can keep moving through
    # their state machines.
    validate on: :create, unless: :allow_unsupported_recipient do
      if unsupported_recipient?
        errors.add(:base, unsupported_recipient_reason)
      end
    end

    # Requirements pulled from https://wise.com/ documentation

    def self.information_required_for(currency)
      fields = []

      fields << {
        type: :text_field,
        key: "account_holder",
        placeholder: "Fiona Hackworth",
        label: "Account holder's full name",
        description: "Must match the name on the bank account exactly"
      }

      fields << {
        type: :text_field,
        key: "bank_name",
        placeholder: "Silicon Valley Bank",
        label: "Name of financial institution"
      }

      if currency.in?(%w[AED BGN CHF CZK DKK EGP EUR GBP GEL HUF ILS NOK PKR PLN RON SEK TRY UAH TND])
        fields << { type: :text_field, key: "account_number", placeholder: "TR330006100519786457841326", label: "IBAN" }
      elsif currency.in?(%w[HKD NGN NPR NZD PHP THB])
        fields << ACCOUNT_NUMBER_FIELD
      elsif currency == "ARS"
        fields << { type: :text_field, key: "account_number", placeholder: "123456789", label: "Account number (CBU)" }
      elsif currency == "AUD"
        fields << { type: :text_field, key: "branch_number", placeholder: "123456", label: "BSB code" }
        fields << ACCOUNT_NUMBER_FIELD
      elsif currency == "BRL"
        fields << { type: :text_field, key: "branch_number", label: "Branch code" }
        fields << ACCOUNT_NUMBER_FIELD
        fields << { type: :select, key: "account_type", label: "Account type", options: { "Checking": "checking", "Savings": "savings" } }
      elsif currency == "CAD"
        fields << { type: :select, key: "account_type", label: "Account type", options: { "Bank Account": "bank_account", "Interac e-Transfer": "interac" } }
        fields << { type: :text_field, key: "institution_number", placeholder: "123", label: "Institution number", conditional: "account_type != 'interac'" }
        fields << { type: :text_field, key: "branch_number", placeholder: "45678", label: "Branch number", conditional: "account_type != 'interac'" }
        fields << { type: :text_field, key: "account_number", placeholder: "123456789", label: "Account number", conditional: "account_type != 'interac'" }
        fields << { type: :text_field, key: "interac_email", placeholder: "fionah@gmail.com", label: "Interac email", conditional: "account_type == 'interac'" }
      elsif currency == "CLP"
        fields << ACCOUNT_NUMBER_FIELD
        fields << { type: :text_field, key: "rut_number", placeholder: "12345678-9", label: "RUT number" }
        fields << { type: :select, key: "account_type", label: "Account type", options: { "Checking": "checking", "Savings": "savings", "Demand": "demand" } }
      elsif currency == "CNY"
        fields << { type: :select, key: "account_type", label: "Account type", options: { "AliPay": "alipay", "UnionPay": "unionpay" } }
        fields << { type: :text_field, key: "account_number", label: "UnionPay card", conditional: "account_type == 'unionpay'" }
        fields << { type: :text_field, key: "alipay_id", label: "AliPay ID (email or phone number)", conditional: "account_type == 'alipay'" }
      elsif currency == "COP"
        fields << ACCOUNT_NUMBER_FIELD
        fields << { type: :select, key: "account_type", label: "Account type", options: { "Checking": "checking", "Savings": "savings" } }
      elsif currency == "IDR"
        fields << { type: :select, key: "account_type", label: "Account type", options: { "Bank Account": "bank_account", "goPay": "gopay", "OVO": "ovo", "DANA": "dana", "LinkAja": "linkaja", "ShopeePay": "shopeepay" } }
        fields << { type: :text_field, key: "account_number", label: "Bank account number", conditional: "account_type == 'bank_account'" }
        fields << { type: :text_field, key: "mobile_wallet_number", label: "E-wallet number", conditional: "account_type !== 'bank_account'" }
      elsif currency == "JPY"
        fields << { type: :text_field, key: "branch_name", label: "Branch name (if applicable)" }
        fields << { type: :select, key: "account_type", label: "Account type", options: { "(Futsuu) Savings/General": "futsuu", "(Chochiku) Savings deposit": "chochiku", "(Touza) Checking/Current": "touza" } }
        fields << ACCOUNT_NUMBER_FIELD
      elsif currency == "KES"
        fields << { type: :select, key: "account_type", label: "Account type", options: { "M-PESA": "mpesa", "Bank Account": " bank_account" } }
        fields << ACCOUNT_NUMBER_FIELD
      elsif currency == "KRW"
        fields << { type: :date_field, key: "recipient_birthday", label: "Recipient's date of birth" }
        fields << ACCOUNT_NUMBER_FIELD
      elsif currency == "LKR"
        fields << { type: :text_field, key: "branch_name", label: "Branch name" }
        fields << ACCOUNT_NUMBER_FIELD
      elsif currency == "MAD"
        fields << { type: :text_field, key: "account_number", label: "Account number", description: "24-digit RIB number" }
      elsif currency == "MXN"
        fields << { type: :text_field, key: "account_number", label: "Account number", description: "18-digit CLABE number" }
        fields << { type: :text_field, key: "tax_id", label: "CURP number", description: "18-character CURP" }
      elsif currency == "MYR"
        fields << { type: :select, key: "account_type", label: "Account type", options: { "Mobile Number (Duitnow)": "mobile_number_duitnow", "NRIC (Duitnow)": "nirc_duitnow", "BNR (Duitnow)": "bnr_duitnow", "Bank Account": "bank_account" } }
        fields << { type: :text_field, key: "duitnow_id", label: "Duitnow ID", conditional: "account_type != 'bank_account'" }
        fields << { type: :text_field, key: "account_number", label: "Account number", conditional: "account_type == 'bank_account'" }
      elsif currency == "SGD"
        fields << { type: :select, key: "account_type", label: "Account type", options: { "Bank Account": "bank_account", "PayNow (Phone Number)": "paynow_phone", "PayNow (NRIC)": "paynow_nric" } }
        fields << ACCOUNT_NUMBER_FIELD.merge(conditional: "account_type == 'bank_account'")
        fields << { type: :text_field, key: "paynow_phone_number", label: "Phone Number", placeholder: "+6591234567", conditional: "account_type == 'paynow_phone'" }
        fields << { type: :text_field, key: "paynow_nric", label: "NRIC", placeholder: "S1234567D", conditional: "account_type == 'paynow_nric'" }
      elsif currency == "UYU"
        fields << { type: :select, key: "account_type", label: "Account type", options: { "Checking": "checking", "Savings": "savings" } }
        fields << ACCOUNT_NUMBER_FIELD
        fields << { type: :text_field, key: "tax_id", label: "National ID" }
        fields << { type: :text_field, key: "branch_name", label: "Branch name (if applicable)" }
      elsif currency == "VND"
        fields << { type: :text_field, key: "institution_number", label: "Bank code (BIC/SWIFT)", placeholder: "AAAA-BB-CC-123" }
        fields << ACCOUNT_NUMBER_FIELD
      elsif currency == "ZAR"
        fields << { type: :date_field, key: "recipient_birthday", label: "Recipient's date of birth" }
        fields << ACCOUNT_NUMBER_FIELD
      end
      return fields
    end

    def self.recipient_information_accessors
      fields = []
      AVAILABLE_CURRENCIES.each do |currency|
        fields += self.information_required_for(currency)
      end
      fields.collect{ |field| field[:key] }.uniq
    end

    store(:recipient_information, accessors: self.recipient_information_accessors)
  end

  class_methods do
    def unsupported_currencies_supported_by_wire
      @unsupported_currencies_supported_by_wire ||= (Wire::AVAILABLE_CURRENCIES - SUPPORTED_CURRENCIES).sort
    end

    # Every currency we've ever sent via Wise, so existing records still render,
    # but with the ones we no longer support labeled and disabled. The current
    # value is left enabled so an existing record's select still submits it.
    def currency_select_options(selected: nil)
      choices = AVAILABLE_CURRENCIES.map do |currency|
        HasWiseRecipient.unsupported_currency?(currency) ? ["#{currency} (unavailable)", currency] : currency
      end

      { choices:, disabled: UNSUPPORTED_CURRENCIES.keys - [selected] }
    end
  end

  def unsupported_account_type?
    UNSUPPORTED_ACCOUNT_TYPES.key?(account_type)
  end

  def unsupported_account_type_reason
    HasWiseRecipient.unsupported_account_type_reason(account_type)
  end

  def unsupported_currency?
    HasWiseRecipient.unsupported_currency?(currency)
  end

  def unsupported_currency_reason
    HasWiseRecipient.unsupported_currency_reason(currency)
  end

  # Whether new Wise transfers can be sent to this recipient, either because
  # its currency or its payment rail (account type) is unsupported.
  def unsupported_recipient?
    unsupported_currency? || unsupported_account_type?
  end

  def unsupported_recipient_reason
    unsupported_currency_reason || unsupported_account_type_reason
  end

  def wise_recipient_url
    return nil unless wise_recipient_id.present?

    "https://wise.com/recipients/#{CGI.escape(wise_recipient_id)}"
  end

  # Admins paste the recipient's Wise URL (e.g. https://wise.com/recipients/<uuid>?new=undefined),
  # so keep only the UUID
  def normalize_wise_recipient_id
    return unless wise_recipient_id_changed?

    normalized = wise_recipient_id&.strip.presence

    if normalized.nil? || normalized.match?(WISE_RECIPIENT_ID_FORMAT)
      self.wise_recipient_id = normalized
      return
    end

    match = WISE_RECIPIENT_ID_REGEXP.match(normalized)
    self.wise_recipient_id = match[1] if match
  end

  # Postal code formats sourced from https://column.com/docs/international-wires/country-specific-details

  POSTAL_CODE_FORMATS = {
    "US": /\A\d{5}(?:-\d{4})?\z/,
    "CN": /\A\d{6}\z/,
    "JP": /\A\d{3}-\d{4}\z/,
    "FR": /\A\d{5}\z/,
    "DE": /\A\d{5}\z/
  }.freeze

  # Payment rails Wise is currently unable to pay out to. Keys are `account_type`
  # values from `information_required_for`.
  UNSUPPORTED_ACCOUNT_TYPES = {
    "interac"               => "Interac",
    "mobile_number_duitnow" => "Duitnow",
    "nirc_duitnow"          => "Duitnow",
    "bnr_duitnow"           => "Duitnow"
  }.freeze

  def self.unsupported_account_type_reason(account_type)
    rail = UNSUPPORTED_ACCOUNT_TYPES[account_type]
    return nil unless rail

    "Wise transfers via #{rail} are currently not supported due to technical difficulties on Wise's side. We recommend using a local bank transfer via Wise instead. If that isn't possible, please send an international wire."
  end

  # Currencies Wise can no longer pay out to. These stay in
  # AVAILABLE_CURRENCIES so existing transfers and payout methods remain valid
  # (and keep their `recipient_information` accessors); only new ones are
  # rejected.
  UNSUPPORTED_CURRENCIES = {
    # Wise can't fund transfers to overseas mobile wallets (AliPay) via ACH
    # debit, and UnionPay is the only other CNY rail we offer.
    "CNY" => "Wise transfers in CNY are currently not supported. Please send an international wire instead."
  }.freeze

  def self.unsupported_currency?(currency)
    UNSUPPORTED_CURRENCIES.key?(currency)
  end

  def self.unsupported_currency_reason(currency)
    UNSUPPORTED_CURRENCIES[currency]
  end

  ACCOUNT_NUMBER_FIELD = { type: :text_field, key: "account_number", placeholder: "123456789", label: "Account number" }.freeze

  WISE_RECIPIENT_ID_FORMAT = /\A[\h-]{36}\z/
  WISE_RECIPIENT_ID_REGEXP = /wise\.com\/recipients\/([\h-]{36})/

  AVAILABLE_CURRENCIES = %w[AED ARS AUD BGN BRL CAD CHF CLP CNY COP CZK DKK EGP EUR GBP GEL HKD HUF IDR ILS JPY KES KRW LKR MAD MXN MYR NGN NOK NPR NZD PHP PKR PLN RON SEK SGD THB TND TRY UAH UYU VND ZAR].freeze
  # Currencies new Wise transfers and payout methods can be created in
  SUPPORTED_CURRENCIES = (AVAILABLE_CURRENCIES - UNSUPPORTED_CURRENCIES.keys).freeze

end
