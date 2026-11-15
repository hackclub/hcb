# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Application reminder unsubscribe", type: :request do
  let(:application) { create(:event_application) }
  let(:path) { unsubscribe_application_path(application.signed_id(purpose: :unsubscribe)) }

  it "links to a signed, login-free confirmation page and archives only after confirmation" do
    mail = Event::ApplicationMailer.with(application:).incomplete
    expect(mail.body.encoded).to include(path)

    get path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Archive application and stop reminders")
    expect(application.reload).not_to be_archived

    post path
    expect(response).to redirect_to(path)
    expect(application.reload).to be_archived
    follow_redirect!
    expect(response.body).to include("You're unsubscribed")

    expect {
      Event::ApplicationReminderJob.perform_now(application, 1)
    }.not_to have_enqueued_mail(Event::ApplicationMailer, :incomplete)

    archived_at = application.archived_at
    post path
    expect(application.reload.archived_at).to eq(archived_at)
  end

  it "does not archive an application submitted after the email was sent" do
    original_path = path
    application.update!(aasm_state: "submitted")

    post original_path
    expect(application.reload).not_to be_archived
    expect(application).to be_submitted
    follow_redirect!
    expect(response.body).to include("Your application has already been submitted")
  end

  it "rejects unsigned, tampered, and wrong-purpose IDs without changing the application" do
    [application.to_param, "#{application.signed_id(purpose: :unsubscribe)}x", application.signed_id(purpose: :other)].each do |id|
      get unsubscribe_application_path(id)
      expect(response).to have_http_status(:not_found)

      post unsubscribe_application_path(id)
      expect(response).to have_http_status(:not_found)
    end
    expect(application.reload).not_to be_archived
  end
end
