# frozen_string_literal: true

require "rails_helper"

RSpec.describe "donations/receipt", type: :view do
  let(:donation) do
    build_stubbed(:donation, name: "Jane Smith", email: "jane@example.com", amount: 12_34,
                            anonymous: true, created_at: Time.zone.local(2025, 1, 2),
                            in_transit_at: Time.zone.local(2025, 1, 5))
  end

  before { assign(:donation, donation) }

  it "identifies the donor, gross amount, original payment date, and tax status" do
    render template: "donations/receipt", formats: [:pdf]

    text = Nokogiri::HTML(rendered).text
    expect(text).to include("Donation receipt", "Jane Smith", "jane@example.com", "$12.34 USD",
                            "January 5, 2025", donation.public_id, donation.event.name,
                            "81-2908499", "No goods or services were provided")
    expect(text).not_to include("January 2, 2025")
  end

  it "does not describe a non-deductible payment as a tax-deductible gift" do
    donation.tax_deductible = false

    render template: "donations/receipt", formats: [:pdf]

    text = Nokogiri::HTML(rendered).text
    expect(text).to include("Payment receipt", "$12.34 USD")
    expect(text).not_to include("No goods or services", "Thank you for your donation")
  end

  it "uses the recurring donor's identity but the individual donation's amount" do
    donation.recurring_donation = RecurringDonation.new(id: 42, name: "Monthly Donor",
                                                        email: "monthly@example.com", amount: 50_00)

    render template: "donations/receipt", formats: [:pdf]

    text = Nokogiri::HTML(rendered).text
    expect(text).to include("Monthly Donor", "monthly@example.com", "$12.34 USD")
    expect(text).not_to include("Jane Smith", "$50.00")
  end
end
