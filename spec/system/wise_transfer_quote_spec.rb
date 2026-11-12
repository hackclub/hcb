# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Wise transfer USD quote", type: :system do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:placeholder) { "Enter an amount & currency to get an estimate in USD" }

  before do
    create(:organizer_position, user:, event:)
    # The amount field is disabled when the event has no balance.
    allow_any_instance_of(Event).to receive(:balance).and_return(1_000_00)

    session = create(:user_session, user:, expiration_at: 1.day.from_now, verified: true)
    allow_any_instance_of(ApplicationController).to receive(:find_current_session).and_return(session)
  end

  def quote
    find("[data-wise-quote-target=quote]")
  end

  # The quote refreshes on `change`, which fires when the field loses focus.
  def enter_amount(value)
    fill_in "wise_transfer[amount]", with: value
    find_field("wise_transfer[amount]").send_keys(:tab)
  end

  it "quotes the entered amount and currency, and returns to the placeholder once the amount is cleared" do
    allow(WiseTransfer).to receive(:generate_quote) { |money| Money.from_amount(money.amount * 2, "USD") }

    visit new_event_wise_transfer_path(event)
    expect(quote).to have_text(placeholder, exact: true)

    select "EUR", from: "wise_transfer[currency]"
    enter_amount "12.5"

    expect(quote).to have_text("Approximately $25.00 USD", exact: true)
    expect(WiseTransfer).to have_received(:generate_quote).with(Money.from_amount(12.5, "EUR"))

    enter_amount ""
    expect(quote).to have_text(placeholder, exact: true)
  end

  it "shows an error instead of a stale or loading quote when Wise fails" do
    allow(WiseTransfer).to receive(:generate_quote).and_raise(Faraday::ConnectionFailed, "Wise is down")

    visit new_event_wise_transfer_path(event)
    select "EUR", from: "wise_transfer[currency]"

    enter_amount "10"
    expect(quote).to have_text("Couldn't load a quote from Wise", exact: true)

    # The 500 is the point of this spec; don't let Capybara re-raise it on teardown.
    Capybara.current_session.server.reset_error!
  end

  it "keeps the latest quote when an earlier, slower one arrives after it" do
    release_slow_quote = Concurrent::Event.new
    slow_quote_returned = Concurrent::Event.new

    allow(WiseTransfer).to receive(:generate_quote) do |money|
      if money.amount == 100
        release_slow_quote.wait(10)
        slow_quote_returned.set
        Money.from_amount(1, "USD")
      else
        Money.from_amount(2, "USD")
      end
    end

    visit new_event_wise_transfer_path(event)
    select "EUR", from: "wise_transfer[currency]"

    enter_amount "100"
    expect(quote).to have_text("Loading quote from Wise...", exact: true)

    enter_amount "200"
    expect(quote).to have_text("Approximately $2.00 USD", exact: true)

    release_slow_quote.set
    expect(slow_quote_returned.wait(10)).to be(true)

    # Give the browser a beat to (wrongly) apply the slow response.
    sleep 0.5
    expect(quote).to have_text("Approximately $2.00 USD", exact: true)
  end
end
