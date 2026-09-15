# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ExportsController", type: :request do
  # Requesting an export with an `email` param creates a User for it, so it is
  # an unauthenticated account creation path and carries the same requirement
  # as the signup forms: the form has to have been rendered first.
  let(:event) { create(:event, is_public: true) }

  def visit_collect_email_form
    get collect_email_exports_path(event_slug: event.slug, file_extension: "csv")
  end

  describe "GET /exports/:event.csv with an email" do
    # The email branch only runs for exports large enough to be queued, which
    # is what makes the request create a User rather than stream a file.
    before do
      allow_any_instance_of(Export::Event::Transactions::Csv).to receive(:async?).and_return(true)
    end

    it "creates no user when the client never rendered the form" do
      email = "scripted-#{SecureRandom.hex(4)}@example.invalid"

      expect {
        get "/exports/#{event.slug}.csv", params: { email: }
      }.to change { User.count }.by(0)

      expect(User.find_by(email:)).to be_nil
    end

    it "queues the export once the form has been rendered" do
      email = "requester-#{SecureRandom.hex(4)}@example.invalid"
      visit_collect_email_form

      expect {
        get "/exports/#{event.slug}.csv", params: { email: }
      }.to change { User.count }.by(1)

      expect(User.find_by(email:)).to be_present
    end
  end

  describe "GET /exports/:event.csv without an email" do
    it "leaves an ordinary export, which creates no user, unaffected" do
      get "/exports/#{event.slug}.csv"

      expect(flash[:error]).to be_blank
      expect(response).to have_http_status(:ok)
    end
  end
end
