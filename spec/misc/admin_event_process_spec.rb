# frozen_string_literal: true

require "rails_helper"

# The organizations table opens #event_process in a modal (a lazy turbo frame)
# and passes its own URL as `return_to` so approving/rejecting lands the admin
# back on the same page of results.
RSpec.describe AdminController, type: :controller do
  include SessionSupport
  render_views

  before { create_session(create(:user, :make_admin), verified: true) }

  describe "#event_process" do
    let(:event) { create(:event, aasm_state: :approved) }

    it "renders inside the modal's frame without the admin layout" do
      frame_id = ActionView::RecordIdentifier.dom_id(event, :event_process_frame)
      request.headers["Turbo-Frame"] = frame_id
      get :event_process, params: { id: event.friendly_id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(id="#{frame_id}"))
      # The layout's sidebar must not be re-rendered inside the modal.
      expect(response.body).not_to include("HCB Admin")
    end

    it "still renders standalone with the layout" do
      get :event_process, params: { id: event.friendly_id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("HCB Admin")
    end

    it "carries return_to through to the action buttons" do
      get :event_process, params: { id: event.friendly_id, return_to: "/admin/events?page=3" }

      expect(response.body).to include(%(value="/admin/events?page=3"))
    end
  end

  describe "#event_toggle_approved" do
    let(:event) { create(:event, aasm_state: :pending) }

    it "returns to the organizations table when it was opened from there" do
      put :event_toggle_approved, params: { id: event.id, return_to: "/admin/events?page=3" }

      expect(response).to redirect_to("/admin/events?page=3")
      expect(flash[:success]).to be_present
    end

    it "falls back to the standalone page without return_to" do
      put :event_toggle_approved, params: { id: event.id }

      expect(response).to redirect_to(event_process_admin_path(event))
    end

    it "refuses to bounce off-host" do
      put :event_toggle_approved, params: { id: event.id, return_to: "//evil.example.com" }

      expect(response).to redirect_to(event_process_admin_path(event))
    end
  end

  describe "#event_reject" do
    let(:event) { create(:event, aasm_state: :pending) }

    it "returns to the organizations table when it was opened from there" do
      put :event_reject, params: { id: event.id, return_to: "/admin/events?q=hack" }

      expect(response).to redirect_to("/admin/events?q=hack")
      expect(event.reload).to be_rejected
    end
  end

  describe "the organizations table" do
    it "opens the review modal instead of navigating away" do
      event = create(:event, aasm_state: :approved)

      get :events

      modal_id = ActionView::RecordIdentifier.dom_id(event, :event_process_modal)

      # The trigger points at the modal, not at the standalone page.
      expect(response.body).to include(%(<a rel="modal:open" href="##{modal_id}">Review</a>))
      # Lazy, so a page of organizations doesn't fire a request per row.
      expect(response.body).to include(%(loading="lazy"))
      expect(response.body).to include(CGI.escapeHTML(event_process_admin_path(event, return_to: "/admin/events")))
    end
  end
end
