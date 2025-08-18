# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotifyEventsWithNegativeBalanceJob do
  include ActionMailer::TestHelper

  it "sends an email to events with a negative balance" do
    admin = create(:user, :make_admin)

    _event1 = create(:event, :with_positive_balance, name: "Event with positive balance")

    event2 = create(:event, name: "Event with negative balance")
    user = create(:user, full_name: "Event Organizer", email: "organizer@example.com")
    create(:organizer_position, event: event2, user:)
    # Create a card grant with an admin user that makes the balance negative
    create(:card_grant, amount_cents: 12_34, event: event2, sent_by: admin)

    sent_emails = capture_emails do
      described_class.new.perform
    end

    negative_balance_email = sent_emails.sole
    expect(negative_balance_email.recipients).to contain_exactly("organizer@example.com")
    expect(negative_balance_email.subject).to eq("Event with negative balance has a negative balance")
    expect(negative_balance_email.html_part.body.to_s).to include("-$12.34")
  end
end
