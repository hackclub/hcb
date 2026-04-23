# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::ReportsController do
  include SessionSupport

  describe "#update" do
    context "when event_id is changed to an event the user does not belong to" do
      it "blocks the event change and leaves the report on its original event" do
        attacker = create(:user)
        attacker_event = create(:event)
        create(:organizer_position, user: attacker, event: attacker_event)
        victim_event = create(:event)

        report = create(:reimbursement_report, user: attacker, event: attacker_event)
        # Pin the "open" state that ReportPolicy#update? (creator && open)
        # passes on. If the factory default ever stops producing an open
        # report, this regression test would silently become vacuous.
        expect(report.aasm_state).to eq("draft")

        sign_in(attacker)

        patch(:update, params: {
                id: report.id,
                reimbursement_report: { event_id: victim_event.id }
              })

        expect(flash[:error]).to match(/not authorized/i)
        expect(report.reload.event).to eq(attacker_event)
      end
    end

    context "when event_id is changed to an event the user manages" do
      it "allows the update" do
        user = create(:user)
        source_event = create(:event)
        create(:organizer_position, user:, event: source_event)
        destination_event = create(:event)
        create(:organizer_position, user:, event: destination_event)

        report = create(:reimbursement_report, user:, event: source_event)

        sign_in(user)

        patch(:update, params: {
                id: report.id,
                reimbursement_report: { event_id: destination_event.id }
              })

        expect(report.reload.event).to eq(destination_event)
      end
    end

    context "when event_id is changed to an event where the user is only a member (not manager)" do
      it "blocks the event change" do
        user = create(:user)
        source_event = create(:event)
        create(:organizer_position, user:, event: source_event)
        destination_event = create(:event)
        create(:organizer_position, user:, event: destination_event, role: :member)

        report = create(:reimbursement_report, user:, event: source_event)

        sign_in(user)

        patch(:update, params: {
                id: report.id,
                reimbursement_report: { event_id: destination_event.id }
              })

        expect(flash[:error]).to match(/not authorized/i)
        expect(report.reload.event).to eq(source_event)
      end
    end

    context "when the actor is an admin" do
      it "allows changing to any event" do
        admin = create(:user, :make_admin)
        source_event = create(:event)
        destination_event = create(:event)

        report = create(:reimbursement_report, user: admin, event: source_event)

        sign_in(admin)

        patch(:update, params: {
                id: report.id,
                reimbursement_report: { event_id: destination_event.id }
              })

        expect(flash[:error]).to be_blank
        expect(report.reload.event).to eq(destination_event)
      end
    end

    context "when event_id is not changed" do
      it "permits the creator to update other fields" do
        user = create(:user)
        event = create(:event)
        create(:organizer_position, user:, event:)
        report = create(:reimbursement_report, user:, event:, name: "Old Name")

        sign_in(user)

        patch(:update, params: {
                id: report.id,
                reimbursement_report: { report_name: "New Name" }
              })

        expect(report.reload.name).to eq("New Name")
        expect(report.event).to eq(event)
      end
    end

    context "reviewer_id assignment" do
      it "does not assign the reviewer when set by a non-manager creator" do
        creator = create(:user)
        event = create(:event)
        manager = create(:user)
        create(:organizer_position, user: manager, event:)
        report = create(:reimbursement_report, user: creator, event:)

        sign_in(creator)

        patch(:update, params: {
                id: report.id,
                reimbursement_report: { reviewer_id: manager.id }
              })

        expect(report.reload.reviewer_id).to be_nil
      end

      it "allows a manager to assign a reviewer on their own report" do
        manager = create(:user)
        event = create(:event)
        create(:organizer_position, user: manager, event:)
        other_manager = create(:user)
        create(:organizer_position, user: other_manager, event:)
        report = create(:reimbursement_report, user: manager, event:)

        sign_in(manager)

        patch(:update, params: {
                id: report.id,
                reimbursement_report: { reviewer_id: other_manager.id }
              })

        expect(report.reload.reviewer_id).to eq(other_manager.id)
      end

      it "allows a manager to assign a reviewer on someone else's report" do
        creator = create(:user)
        manager = create(:user)
        event = create(:event)
        create(:organizer_position, user: manager, event:)
        other_manager = create(:user)
        create(:organizer_position, user: other_manager, event:)
        report = create(:reimbursement_report, user: creator, event:)

        sign_in(manager)

        patch(:update, params: {
                id: report.id,
                reimbursement_report: { reviewer_id: other_manager.id }
              })

        expect(report.reload.reviewer_id).to eq(other_manager.id)
      end

      it "allows an admin to assign a reviewer" do
        admin = create(:user, :make_admin)
        event = create(:event)
        reviewer = create(:user)
        create(:organizer_position, user: reviewer, event:)
        report = create(:reimbursement_report, user: admin, event:)

        sign_in(admin)

        patch(:update, params: {
                id: report.id,
                reimbursement_report: { reviewer_id: reviewer.id }
              })

        expect(report.reload.reviewer_id).to eq(reviewer.id)
      end
    end
  end
end
