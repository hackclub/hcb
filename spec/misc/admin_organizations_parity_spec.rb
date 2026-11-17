# frozen_string_literal: true

require "rails_helper"

# See spec/support/admin_ui_parity_helpers.rb.
RSpec.describe AdminController, type: :controller do
  include SessionSupport
  include AdminUiParityHelpers
  render_views

  before { create_session(create(:user, :make_admin), verified: true) }

  describe "organization screens submit to the same endpoints with the same params" do
    it "organization: approve/pending toggle and reject are PUTs" do
      pending_event = create(:event, aasm_state: :pending)

      get :event_process, params: { id: pending_event.friendly_id }

      expect(form_fields("put", event_toggle_approved_admin_path(pending_event))).to eq([])
      expect(form_fields("put", event_reject_admin_path(pending_event))).to eq([])
    end

    it "airtable import posts the record ID" do
      get :event_new_from_airtable

      expect(form_fields("post", event_create_from_airtable_admin_index_path)).to eq(["airtable_record_id"])
    end

    it "organization creation posts the same params as before" do
      get :event_new

      expected = %w[
        approved cosigner_email country demo_mode include_videos is_public is_signee
        name organizer_email plan point_of_contact_id risk_level tags[]
      ]
      expect(form_fields("post", event_create_admin_index_path)).to eq(expected)
      # Tags moved from a multi-select to checkboxes; the values must be the
      # same tag names the controller looks up.
      tag_values = page.css("input[type=checkbox][name='tags[]']").map { |i| i["value"] }
      expect(tag_values).to match_array(EventTag::Tags::ALL) if defined?(EventTag::Tags::ALL)
      expect(tag_values).to include("Hackathon", "Hack Club", "Organized by Teenagers")
    end
  end

  describe "organization actions still ask for confirmation" do
    def confirm_for(selector)
      element = page.at_css(selector)
      expect(element).to be_present, "nothing matched #{selector}"
      element["data-turbo-confirm"] || element.ancestors("form").first&.[]("data-turbo-confirm")
    end

    def submit_in(action)
      "form[action='#{action}'] button, form[action='#{action}'] input[type=submit]"
    end

    it "on organization reject" do
      pending_event = create(:event, aasm_state: :pending)

      get :event_process, params: { id: pending_event.friendly_id }

      expect(confirm_for(submit_in(event_reject_admin_path(pending_event)))).to include("can not be undone")
    end

    it "when sending an approved organization back to pending" do
      approved_event = create(:event, aasm_state: :approved)

      get :event_process, params: { id: approved_event.friendly_id }

      expect(confirm_for(submit_in(event_toggle_approved_admin_path(approved_event)))).to include("previously approved")
    end
  end

  describe "organizations table actions" do
    it "both open the same process screen as before" do
      pending_event = create(:event, aasm_state: :pending)

      get :events

      frame = page.at_css("turbo-frame##{ActionView::RecordIdentifier.dom_id(pending_event, :event_process_frame)}")
      expect(URI.parse(frame["src"]).path).to eq(event_process_admin_path(pending_event))
    end
  end
end
