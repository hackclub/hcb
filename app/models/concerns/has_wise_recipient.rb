# frozen_string_literal: true

module HasWiseRecipient
  extend ActiveSupport::Concern

  included do
    include CountryEnumable
    has_country_enum(field: :recipient_country)

    # validate do
    #   unless bic_code.nil? || bic_code.match(/[A-Z]{4}([A-Z]{2})[A-Z0-9]{2}([A-Z0-9]{3})?$/) # https://www.johndcook.com/blog/2024/01/29/swift/
    #     errors.add(:bic_code, "is not a valid SWIFT / BIC code")
    #   end
    # end

    # validate do
    #   if IBAN_FORMATS[bank_country.to_sym] && !account_number.match(IBAN_FORMATS[bank_country.to_sym])
    #     errors.add(:account_number, "does not meet the required format for this country")
    #   end
    # end

    validate do
      if POSTAL_CODE_FORMATS[recipient_country.to_sym] && !address_postal_code.match(POSTAL_CODE_FORMATS[recipient_country.to_sym])
        errors.add(:address_postal_code, "does not meet the required format for this country")
      end
    end

    validate do
      unless currency.in?(AVAILABLE_CURRENCIES)
        errors.add(:currency, "is not supported for Wise transfers")
      end
    end

    # the SWIFT messaging system supports a very limited set of characters.
    # https://column.com/docs/international-wires/#valid-characters-permitted

    # validate do
    #   error = "contains invalid characters; the SWIFT system only supports the English alphabet and numbers."
    #   regex = /[^A-Za-z0-9\-?:( ).,'+\/]/

    #   errors.add(:address_line1, error) if address_line1.match(regex)
    #   errors.add(:address_line2, error) if address_line2.present? && address_line2.match(regex)
    #   errors.add(:address_postal_code, error) if address_postal_code.match(regex)
    #   errors.add(:address_state, error) if address_state.match(regex)

    #   Wire.recipient_information_accessors.excluding("legal_type", "email").each do |recipient_information_accessor|
    #     errors.add(recipient_information_accessor, error) if recipient_information[recipient_information_accessor]&.match(regex)
    #   end
    # end

    # see https://column.com/docs/api/#counterparty/create for valid options, under "legal_type"

    # View https://github.com/hackclub/hcb/issues/9037 for context. Limited in India only, at the moment.

    validate on: :create do
      if recipient_information[:purpose_code].present? && RESTRICTED_PURPOSE_CODES[recipient_country.to_sym]&.include?(recipient_information[:purpose_code])
        errors.add(:purpose_code, "can not be used on HCB, please use a more specific purpose code or contact us.")
      end
    end

    def self.information_required_for(currency) # country can be null, in which case, only the general fields will be returned.
      fields = []

      if currency.in?(%w[AED BGN CHF CZK DKK EGP EUR GBP GEL HUF ILS NOK PKR PLN RON SEK TRY UAH])
        fields << { type: :text_field, key: "account_number", placeholder: "TR330006100519786457841326", label: "IBAN" }
      elsif currency.in?(%w[HKD NGN NPR NZD PHP SGD THB])
        fields << { type: :text_field, key: "account_number", placeholder: "123456789", label: "Account number" }
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
        fields << { type: :text_field, key: "institution_number", placeholder: "123", label: "Institution number" }
        fields << { type: :text_field, key: "branch_number", placeholder: "45678", label: "Branch number" }
        fields << ACCOUNT_NUMBER_FIELD
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

    store_accessor :recipient_information, *self.recipient_information_accessors
  end

  # IBAN & postal code formats sourced from https://column.com/docs/international-wires/country-specific-details

  POSTAL_CODE_FORMATS = {
    "US": /\A\d{5}(?:-\d{4})?\z/,
    "CN": /\A\d{6}\z/,
    "JP": /\A\d{3}-\d{4}\z/,
    "FR": /\A\d{5}\z/,
    "DE": /\A\d{5}\z/
  }.freeze

  ACCOUNT_NUMBER_FIELD = { type: :text_field, key: "account_number", placeholder: "123456789", label: "Account number" }.freeze

  AVAILABLE_CURRENCIES = (::EuCentralBank::CURRENCIES + ["EUR"] - ["USD"]).freeze
end
