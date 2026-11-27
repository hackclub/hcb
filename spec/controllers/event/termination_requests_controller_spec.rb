# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event::TerminationRequestsController do
  include SessionSupport

  let(:event) { create(:event) }
  let(:signee) { create(:user) }
  let(:manager) { create(:user) }

  before do
    create(:organizer_position, user: signee, event:, role: :manager, is_signee: true)
    create(:organizer_position, user: manager, event:, role: :manager)
  end

  describe "#create" do
    it "lets a contract signee request termination" do
      create_session(signee, verified: true)

      expect do
        post :create, params: { event_id: event.slug, event_termination_request: { reason: "We are done." } }
      end.to change(Event::TerminationRequest, :count).by(1)

      request = event.pending_termination_request
      expect(request.requested_by).to eq(signee)
      expect(request.reason).to eq("We are done.")
      expect(response).to redirect_to(edit_event_path(event, tab: "details"))
      expect(flash[:success]).to include("Termination request submitted")
    end

    it "rejects a manager who has not signed the contract" do
      create_session(manager, verified: true)

      expect do
        post :create, params: { event_id: event.slug, event_termination_request: { reason: "We are done." } }
      end.not_to change(Event::TerminationRequest, :count)

      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end

    it "reports a validation error instead of creating a second pending request" do
      create(:event_termination_request, event:, requested_by: signee)
      create_session(signee, verified: true)

      expect do
        post :create, params: { event_id: event.slug, event_termination_request: { reason: "Again." } }
      end.not_to change(Event::TerminationRequest, :count)

      expect(flash[:error]).to eq("This organization already has a pending termination request.")
      expect(response).to redirect_to(edit_event_path(event, tab: "details"))
    end
  end

  describe "#withdraw" do
    let!(:termination_request) { create(:event_termination_request, event:, requested_by: signee) }

    it "lets a signee withdraw the pending request" do
      create_session(signee, verified: true)

      post :withdraw, params: { event_id: event.slug, id: termination_request.id }

      expect(termination_request.reload).to be_withdrawn
      expect(response).to redirect_to(edit_event_path(event, tab: "details"))
      expect(flash[:success]).to eq("Termination request withdrawn.")
    end

    it "rejects a non-signee" do
      create_session(manager, verified: true)

      post :withdraw, params: { event_id: event.slug, id: termination_request.id }

      expect(termination_request.reload).to be_pending
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end
  end
end
