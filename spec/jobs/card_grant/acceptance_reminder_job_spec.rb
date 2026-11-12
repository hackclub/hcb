# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrant::AcceptanceReminderJob, type: :job do
  let(:event) { create(:event) }
  let(:grant) { create(:card_grant, event:, stripe_card: nil, created_at: 7.days.ago) }

  before do
    travel_to Time.zone.local(2026, 3, 31, 12)
    allow_any_instance_of(CardGrant).to receive(:transfer_money)
    allow_any_instance_of(CardGrant).to receive(:send_email)
  end

  it "reminds at each milestone, including the whole day and grants expiring today" do
    due = [7, 14, 30, 90, 180].map do |days|
      create(:card_grant, event:, stripe_card: nil, created_at: days.days.ago.beginning_of_day, expiration_at: Date.current)
    end
    due << create(:card_grant, event:, stripe_card: nil, created_at: 7.days.ago.end_of_day)
    [6, 8, 13, 15, 29, 31, 89, 91, 179, 181, 365].each do |days|
      create(:card_grant, event:, stripe_card: nil, created_at: days.days.ago)
    end

    perform_enqueued_jobs(only: MailDeliveryJob) { described_class.perform_now }

    expect(ActionMailer::Base.deliveries.flat_map(&:to)).to match_array(due.map { |grant| grant.user.email })
  end

  it "skips accepted, canceled, expired, and blocked fraudulent grants" do
    create(:card_grant, event:, created_at: 7.days.ago)
    create(:card_grant, event:, stripe_card: nil, created_at: 7.days.ago, status: :canceled)
    create(:card_grant, event:, stripe_card: nil, created_at: 7.days.ago, status: :expired)
    create(:card_grant, event:, stripe_card: nil, created_at: 7.days.ago, expiration_at: Date.yesterday)
    fraudulent = create(:card_grant, event:, stripe_card: nil, created_at: 7.days.ago, pre_authorization_required: true)
    fraudulent.pre_authorization.update!(aasm_state: "fraudulent", product_url: "https://example.com")

    expect { described_class.perform_now }.not_to have_enqueued_mail(CardGrantMailer, :acceptance_reminder)
  end

  it "sends the amount, purpose, deadline, and acceptance link to the recipient" do
    grant.update!(amount_cents: 12_345, purpose: "Workshop supplies", expiration_at: Date.new(2026, 4, 15))

    perform_enqueued_jobs(only: MailDeliveryJob) { described_class.perform_now }

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([grant.user.email])
    expect(mail.subject).to eq("[#{event.name}] Reminder to accept your $123.45 grant")
    body = Nokogiri::HTML(mail.html_part.body.decoded)
    expect(body.text).to include("$123.45", event.name, "Workshop supplies", "April 15, 2026")
    expect(body.at_css("a:contains('Accept your grant')")["href"])
      .to eq(Rails.application.routes.url_helpers.card_grant_url(grant, email: grant.user.email))
  end

  [:accepted, :canceled, :expired, :fraudulent].each do |state|
    it "does not send if the grant becomes #{state} after queueing" do
      grant
      described_class.perform_now
      case state
      when :accepted
        grant.update!(stripe_card: create(:stripe_card, :with_stripe_id, event:, skip_notify_user: true))
      when :canceled
        grant.update!(status: :canceled)
      when :expired
        grant.update!(expiration_at: Date.current)
        travel 1.day # The expiration job has not updated the status yet.
      when :fraudulent
        grant.update!(pre_authorization_required: true)
        grant.create_pre_authorization!(aasm_state: "fraudulent", product_url: "https://example.com")
      end

      expect { perform_enqueued_jobs(only: MailDeliveryJob) }.not_to change(ActionMailer::Base.deliveries, :count)
    end
  end
end
