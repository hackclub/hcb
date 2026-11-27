# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::TerminationRequestsController do
  include SessionSupport
  render_views

  let(:admin) { create(:user, :make_admin) }
  let(:event) { create(:event, name: "Lion City Hacks") }
  let(:signee) { create(:user, full_name: "Orpheus Dinosaur") }

  describe "#index" do
    it "lists requests with pending ones first" do
      create_session(admin, verified: true)
      pending = create(:event_termination_request, event:, requested_by: signee)
      withdrawn = create(:event_termination_request, event: create(:event, name: "Daydream"), requested_by: signee)
      withdrawn.withdraw!
      pending.update!(created_at: 2.days.ago)

      get :index

      expect(response).to have_http_status(:ok)
      rows = response.parsed_body.css("table tbody tr").map { |tr| tr.css("td").first.text.strip }
      expect(rows).to eq(["Lion City Hacks", "Daydream"])
    end

    it "is not available to organizers" do
      create_session(signee, verified: true)

      get :index

      expect(response).not_to have_http_status(:ok)
    end
  end

  describe "#close and #reopen" do
    let(:termination_request) { create(:event_termination_request, event:, requested_by: signee) }

    it "closes and reopens a request" do
      create_session(admin, verified: true)

      post :close, params: { id: termination_request.id }
      expect(termination_request.reload).to be_closed
      expect(termination_request.closed_by).to eq(admin)
      expect(response).to redirect_to(admin_termination_request_path(termination_request))

      post :reopen, params: { id: termination_request.id }
      expect(termination_request.reload).to be_pending
    end
  end
end
