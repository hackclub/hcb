# frozen_string_literal: true

# Loads the Hack Club "yellow pages" merchant database (a mapping of card
# network acceptor IDs to human-readable merchant names) that ships vendored at
# lib/data/yellow_pages_merchants.yaml.
#
# Source: https://github.com/hackclub/yellow_pages/blob/main/lib/yellow_pages/merchants.yaml
#
# Used by the transaction simulator to let you pick a real merchant to attach to
# a simulated Stripe authorization.
module YellowPagesMerchants
  PATH = Rails.root.join("lib", "data", "yellow_pages_merchants.yaml")

  Merchant = Struct.new(:name, :network_id, keyword_init: true)

  # Returns an array of Merchant structs (name + a representative network_id),
  # only including entries that have a name, sorted alphabetically.
  def self.all
    @all ||= raw
             .select { |entry| entry["name"].present? && entry["network_ids"].present? }
             .map { |entry| Merchant.new(name: entry["name"], network_id: entry["network_ids"].first) }
             .sort_by { |merchant| merchant.name.downcase }
  end

  def self.find_by_network_id(network_id)
    all.find { |merchant| merchant.network_id == network_id }
  end

  def self.raw
    YAML.safe_load_file(PATH)
  end
end
