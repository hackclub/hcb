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

        create_session(attacker, verified: true)

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

        create_session(user, verified: true)

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

        create_session(user, verified: true)

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

        create_session(admin, verified: true)

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

        create_session(user, verified: true)

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

        create_session(creator, verified: true)

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

        create_session(manager, verified: true)

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

        create_session(manager, verified: true)

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

        create_session(admin, verified: true)

        patch(:update, params: {
                id: report.id,
                reimbursement_report: { reviewer_id: reviewer.id }
              })

        expect(report.reload.reviewer_id).to eq(reviewer.id)
      end
    end
  end

  describe "#update_payout_method" do
    def ach(account: "12345678")
      LegalEntity::PayoutMethod::AchTransfer.new(account_number: account, routing_number: "021000021")
    end

    it "changes a draft report's payout method to one of the user's methods" do
      user = create(:user)
      default_pm = user.personal_legal_entity.payout_methods.create!(default: true, details: ach)
      other_pm = user.personal_legal_entity.payout_methods.create!(default: false, details: ach(account: "99999999"))
      report = create(:reimbursement_report, user:, event: create(:event), aasm_state: :draft)
      expect(report.legal_entity_payout_method).to eq(default_pm)

      create_session(user, verified: true)

      post(:update_payout_method, params: { report_id: report.id, legal_entity_payout_method_id: other_pm.id })

      expect(report.reload.legal_entity_payout_method).to eq(other_pm)
    end

    it "converts the report and its expenses when switching to a different-currency method" do
      stub_request(:get, /api\.column\.com\/institutions/)
        .to_return(status: 200, body: { country_code: "GB" }.to_json, headers: { "Content-Type" => "application/json" })

      user = create(:user)
      user.personal_legal_entity.payout_methods.create!(default: true, details: ach)
      wise = user.personal_legal_entity.payout_methods.create!(
        default: false,
        details: LegalEntity::PayoutMethod::WiseTransfer.new(
          address_line1: "1 Main St", address_city: "London", address_state: "England",
          address_postal_code: "SW1A 1AA", recipient_country: 1, currency: "GBP"
        )
      )
      report = create(:reimbursement_report, user:, event: create(:event), aasm_state: :draft)

      create_session(user, verified: true)

      post(:update_payout_method, params: { report_id: report.id, legal_entity_payout_method_id: wise.id })

      expect(report.reload.currency).to eq("GBP")
      expect(report.legal_entity_payout_method).to eq(wise)
    end

    it "refuses to assign a payout method belonging to another user" do
      user = create(:user)
      own_pm = user.personal_legal_entity.payout_methods.create!(default: true, details: ach)
      report = create(:reimbursement_report, user:, event: create(:event), aasm_state: :draft)

      stranger = create(:user)
      stranger_pm = stranger.personal_legal_entity.payout_methods.create!(default: true, details: ach)

      create_session(user, verified: true)

      post(:update_payout_method, params: { report_id: report.id, legal_entity_payout_method_id: stranger_pm.id })

      expect(flash[:error]).to eq("Payout method not found.")
      expect(report.reload.legal_entity_payout_method).to eq(own_pm)
    end

    it "refuses to assign an archived payout method" do
      user = create(:user)
      default_pm = user.personal_legal_entity.payout_methods.create!(default: true, details: ach)
      archived = user.personal_legal_entity.payout_methods.create!(default: false, archived: true, details: ach(account: "99999999"))
      report = create(:reimbursement_report, user:, event: create(:event), aasm_state: :draft)

      create_session(user, verified: true)

      post(:update_payout_method, params: { report_id: report.id, legal_entity_payout_method_id: archived.id })

      expect(flash[:error]).to eq("Payout method not found.")
      expect(report.reload.legal_entity_payout_method).to eq(default_pm)
    end

    it "is not authorized once the report is no longer a draft" do
      user = create(:user)
      default_pm = user.personal_legal_entity.payout_methods.create!(default: true, details: ach)
      other_pm = user.personal_legal_entity.payout_methods.create!(default: false, details: ach(account: "99999999"))
      report = create(:reimbursement_report, user:, event: create(:event), aasm_state: :submitted)

      create_session(user, verified: true)

      post(:update_payout_method, params: { report_id: report.id, legal_entity_payout_method_id: other_pm.id })

      expect(flash[:error]).to match(/not authorized/i)
      expect(report.reload.legal_entity_payout_method).to eq(default_pm)
    end
  end
end
