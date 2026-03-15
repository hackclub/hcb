# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotifyEventsWithNegativeBalanceJob do
  include ActionMailer::TestHelper

  it "sends an email to events with a negative balance" do
    admin = create(:user, :make_admin)
    create(:governance_admin_transfer_limit, user: admin)

    # A standard event with a positive balance
    event1 = create(:event, :with_positive_balance, name: "Event with positive balance")
    event1_user = create(:user, full_name: "Organizer One", email: "organizer-1@example.com")
    create(:organizer_position, event: event1, user: event1_user)

    # A standard event with a negative balance
    event2 = create(:event, name: "Event with negative balance")
    event2_user = create(:user, full_name: "Organizer Two", email: "organizer-2@example.com")
    create(:organizer_position, event: event2, user: event2_user)
    # Create a card grant with an admin user that makes the balance negative
    create(:card_grant, amount_cents: 12_34, event: event2, sent_by: admin)
    expect(event2.balance).to eq(-12_34)

    # An internal event with a negative balance
    event3 = create(:event, name: "Internal event with negative balance", plan_type: Event::Plan::Internal)
    event3_user = create(:user, full_name: "Internal User", email: "internal@example.com")
    create(:organizer_position, event: event3, user: event3_user)
    # Create a card grant with an admin user that makes the balance negative
    create(:card_grant, amount_cents: 56_78, invite_message: "This will make your balance negative", event: event3, sent_by: admin)
    expect(event3.balance).to eq(-56_78)

    sent_emails = capture_emails do
      Sidekiq::Testing.inline! do
        described_class.perform_async
      end
    end

    negative_balance_email = sent_emails.sole
    expect(negative_balance_email.recipients).to contain_exactly(event2_user.email)
    expect(negative_balance_email.subject).to eq("Event with negative balance has a negative balance")
    expect(negative_balance_email.html_part.body.to_s).to include("-$12.34")
  end

  it "includes the point of contact if present" do
    admin = create(:user, :make_admin, full_name: "Admin User", email: "admin@example.com")
    create(:governance_admin_transfer_limit, user: admin)

    event = create(:event, name: "Event with negative balance", point_of_contact: admin)
    user = create(:user, full_name: "Event Organizer", email: "organizer@example.com")
    create(:organizer_position, event:, user:)
    # Create a card grant with an admin user that makes the balance negative
    create(:card_grant, amount_cents: 12_34, invite_message: "This will make your balance negative", event:, sent_by: admin)
    expect(event.balance).to eq(-12_34)

    sent_emails = capture_emails do
      Sidekiq::Testing.inline! do
        described_class.perform_async
      end
    end

    parsed_body = Nokogiri::HTML5.fragment(sent_emails.sole.html_part.body.to_s)
    mailto = parsed_body.css("a[href^='mailto:admin@example.com']").sole
    expect(mailto.text).to eq("Admin User")
  end
end
