# frozen_string_literal: true

module MoneyService
  def self.convert_to_usd(amount_cents, currency)
    return amount_cents if currency == "USD"

    if currency.in?(EuCentralBank::CURRENCIES)
      eu_bank = EuCentralBank.new
      if Rails.env.test?
        eu_bank.update_rates(Rails.root.join("spec/fixtures/files/eurofxref-daily.xml"))
      else
        eu_bank.update_rates
      end
      return eu_bank.exchange(amount_cents, currency, "USD").cents
    else
      # we fallback to Wise for currency conversion when we can't get it from the EU Central Bank
      money = Money.from_cents(amount_cents, currency)
      return WiseTransfer.generate_detailed_quote(money)[:without_fees_usd_amount].cents
    end
  end

  def self.convert_from_usd(usd_amount_cents, currency)
    return usd_amount_cents if currency == "USD"

    money = Money.from_cents(usd_amount_cents, "USD")
    WiseTransfer.convert_usd_to_local(money, currency).cents
  end
end
