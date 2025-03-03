# frozen_string_literal: true

module StripeAuthorizationsHelper
  def is_city_or_phone?(str)
    return nil if str.blank?

    has_digits = str.scan(/\d/).any?
    has_digits ? :phone : :city
  end

  def humanized_merchant_name(merchant)
    yp_merchant = YellowPages::Merchant.lookup(network_id: merchant["network_id"])

    yp_merchant.name || merchant["name"].titleize
  end

  def humanized_category(merchant)
    yp_category = YellowPages::Category.lookup(code: merchant["category_code"])

    StatsD.event("CategoryNotFound", merchant["category_code"]) unless yp_category.name

    yp_category.name || merchant["category"].humanize
  end
end
