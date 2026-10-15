# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::ReportsController do
  include SessionSupport

  describe "#assign_to_me" do
    let(:manager) { create(:user) }
    let(:event) { create(:event, organizers: [manager]) }
    let(:bot) { create(:user) }
    let(:report) { create(:reimbursement_report, event:, reviewer: bot, aasm_state: :submitted) }

    it "lets a manager take over a report assigned to someone else" do
      create_session(manager, verified: true)

      post(:assign_to_me, params: { report_id: report.id })

      expect(report.reload.reviewer).to eq(manager)
      expect(report.submitted?).to be(true)
      expect(response).to redirect_to(reimbursement_report_path(report))
      expect(flash[:success]).to eq("Report assigned to you for review.")
    end

    it "lets a parent-organization manager take over a report" do
      child = create(:event, parent: event)
      report.update!(event: child)
      create_session(manager, verified: true)

      post(:assign_to_me, params: { report_id: report.id })

      expect(report.reload.reviewer).to eq(manager)
    end

    it "does not allow a manager to take over their own reimbursement" do
      report.update!(user: manager)
      create_session(manager, verified: true)

      post(:assign_to_me, params: { report_id: report.id })

      expect(report.reload.reviewer).to eq(bot)
      expect(flash[:error]).to match(/not authorized/i)
    end

    it "does not allow an ordinary member to take over a report" do
      member = create(:user)
      create(:organizer_position, user: member, event:, role: :member)
      create_session(member, verified: true)

      post(:assign_to_me, params: { report_id: report.id })

      expect(report.reload.reviewer).to eq(bot)
      expect(flash[:error]).to match(/not authorized/i)
    end

    it "does not allow a manager from another organization to take over a report" do
      stranger = create(:user)
      create(:event, organizers: [stranger])
      create_session(stranger, verified: true)

      post(:assign_to_me, params: { report_id: report.id })

      expect(report.reload.reviewer).to eq(bot)
      expect(flash[:error]).to match(/not authorized/i)
    end

    it "does not change the reviewer of a report that has already been reviewed" do
      report.update!(aasm_state: :reimbursement_requested)
      create_session(manager, verified: true)

      post(:assign_to_me, params: { report_id: report.id })

      expect(report.reload.reviewer).to eq(bot)
      expect(flash[:error]).to match(/not authorized/i)
    end
  end

  describe "reviewer selection" do
    render_views

    let(:manager) { create(:user) }
    let(:event) do
      create(:event, plan_type: Event::Plan::HackClubAffiliate, organizers: [manager],
                     public_reimbursement_page_enabled: true, reimbursements_allow_reviewer_selection: false)
    end
    let(:user) { create(:user) }
    let(:report) do
      user.personal_legal_entity.payout_methods.create!(
        default: true,
        details: LegalEntity::PayoutMethod::AchTransfer.new(account_number: "12345678", routing_number: "021000021")
      )
      create(:reimbursement_report, user:, event:).tap do |report|
        expense = create(:reimbursement_expense, report:, value: 12.34, category: "Project Supplies")
        ReceiptService::Create.new(receiptable: expense, uploader: user, attachments: [file_fixture("receipt.png")], upload_method: :receipts_page).run!
      end
    end

    it "hides reviewer selection from submitters when disabled" do
      create_session(user, verified: true)

      get(:show, params: { id: report.id })

      expect(response).to have_http_status(:ok)
      expect(Nokogiri::HTML5(response.body).css('select[name*="reviewer_id"]')).to be_empty
      expect(response.body).not_to include("Assign to me")
    end

    it "allows submission without a reviewer and ignores a forged reviewer parameter when disabled" do
      create_session(user, verified: true)

      expect {
        post(:submit, params: { report_id: report.id, reviewer_id: manager.public_id })
      }.to have_enqueued_mail(ReimbursementMailer, :review_requested)

      expect(report.reload.submitted?).to be(true)
      expect(report.reviewer).to be_nil
      expect(flash[:error]).to be_nil
    end

    it "keeps the existing reviewer choice when the setting is enabled" do
      event.update!(reimbursements_allow_reviewer_selection: true)
      create_session(user, verified: true)

      get(:show, params: { id: report.id })
      expect(Nokogiri::HTML5(response.body).css('select[name="reviewer_id"]')).not_to be_empty

      post(:submit, params: { report_id: report.id, reviewer_id: manager.public_id })

      expect(report.reload.submitted?).to be(true)
      expect(report.reviewer).to eq(manager)
    end

    it "ignores reviewer selection supplied by a submitter when creating a report with selection disabled" do
      create_session(user, verified: true)

      post(:create, params: { reimbursement_report: { event_id: event.id, email: user.email, report_name: "Supplies", reviewer_id: manager.public_id } })

      expect(Reimbursement::Report.last.reviewer).to be_nil
      expect(Reimbursement::Report.last.name).to eq("Supplies")
    end

    it "still lets managers assign a reviewer when creating a report with selection disabled" do
      create_session(manager, verified: true)

      post(:create, params: { reimbursement_report: { event_id: event.id, email: user.email, report_name: "Supplies", reviewer_id: manager.public_id } })

      expect(Reimbursement::Report.last.reviewer).to eq(manager)
    end

    it "still lets managers reassign existing reports with selection disabled" do
      report.update!(reviewer: create(:user), aasm_state: :submitted)
      create_session(manager, verified: true)

      get(:show, params: { id: report.id })
      expect(response.body).to include("Assign to me")

      patch(:update, params: { id: report.id, reimbursement_report: { reviewer_id: manager.id } })

      expect(report.reload.reviewer).to eq(manager)
    end

    it "does not let a submitter bypass the setting through the update endpoint" do
      create_session(user, verified: true)

      patch(:update, params: { id: report.id, reimbursement_report: { reviewer_id: manager.id } })

      expect(report.reload.reviewer).to be_nil
    end
  end

  describe "#start" do
    render_views

    def email_field_value(body)
      Nokogiri::HTML5(body).at_css('input[name="reimbursement_report[email]"]')&.[]("value")
    end

    it "prefills the email field when signed in" do
      event = create(:event, public_reimbursement_page_enabled: true)
      user = create(:user, email: "fiona@example.com")
      create_session(user, verified: true)

      get(:start, params: { event_name: event.slug })

      expect(response).to have_http_status(:ok)
      expect(email_field_value(response.body)).to eq("fiona@example.com")
    end

    it "does not prefill the email field when signed in as an organizer" do
      user = create(:user, email: "fiona@example.com")
      event = create(:event, public_reimbursement_page_enabled: true, organizers: [user])
      create_session(user, verified: true)

      get(:start, params: { event_name: event.slug })

      expect(response).to have_http_status(:ok)
      expect(email_field_value(response.body)).to be_blank
    end

    it "does not prefill the email field when signed out" do
      event = create(:event, public_reimbursement_page_enabled: true)

      get(:start, params: { event_name: event.slug })

      expect(response).to have_http_status(:ok)
      expect(email_field_value(response.body)).to be_blank
    end
  end

  describe "#show" do
    render_views

    def header_badges(body)
      Nokogiri::HTML5(body).css("h3 .badge").map { |badge| badge.text.squish }
    end

    it "shows a single review requested badge naming the assigned reviewer" do
      creator = create(:user)
      event = create(:event)
      reviewer = create(:user, full_name: "Fiona Hackworth")
      create(:organizer_position, user: reviewer, event:)
      report = create(:reimbursement_report, user: creator, event:, reviewer:, aasm_state: :submitted)

      create_session(creator, verified: true)

      get(:show, params: { id: report.id })

      expect(response).to have_http_status(:ok)
      expect(header_badges(response.body)).to eq(["Review requested from Fiona H"])
    end

    it "shows the status badge when no reviewer is assigned" do
      creator = create(:user)
      event = create(:event)
      report = create(:reimbursement_report, user: creator, event:, aasm_state: :submitted)

      create_session(creator, verified: true)

      get(:show, params: { id: report.id })

      expect(response).to have_http_status(:ok)
      expect(header_badges(response.body)).to eq(["Review Requested"])
    end
  end

  describe "#edit" do
    render_views

    context "when the report is backed by a card grant" do
      it "disables the organization select and explains why" do
        admin = create(:user, :make_admin)
        event = create(:event)
        card_grant = create(:card_grant, event:, user: admin, sent_by: admin)
        report = create(:reimbursement_report, user: admin, event:, card_grant:)

        create_session(admin, verified: true)

        get(:edit, params: { id: report.id })
        select_tag = response.body[/<select[^>]*name="reimbursement_report\[event_id\]"[^>]*>/]

        expect(response).to have_http_status(:ok)
        expect(select_tag).to be_present
        expect(select_tag).to include('disabled="disabled"')
        expect(response.body).to include("backed by a card grant")
      end
    end

    context "when the report is not backed by a card grant" do
      it "leaves the organization select enabled" do
        admin = create(:user, :make_admin)
        event = create(:event)
        report = create(:reimbursement_report, user: admin, event:)

        create_session(admin, verified: true)

        get(:edit, params: { id: report.id })
        select_tag = response.body[/<select[^>]*name="reimbursement_report\[event_id\]"[^>]*>/]

        expect(response).to have_http_status(:ok)
        expect(select_tag).to be_present
        expect(select_tag).not_to include("disabled")
        expect(response.body).not_to include("backed by a card grant")
      end
    end
  end

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

    context "when the report is backed by a card grant" do
      it "blocks changing the event even for admins" do
        admin = create(:user, :make_admin)
        source_event = create(:event)
        destination_event = create(:event)
        card_grant = create(:card_grant, event: source_event, user: admin, sent_by: admin)
        report = create(:reimbursement_report, user: admin, event: source_event, card_grant:)

        create_session(admin, verified: true)

        patch(:update, params: {
                id: report.id,
                reimbursement_report: { event_id: destination_event.id }
              })

        expect(flash[:error]).to match(/not authorized/i)
        expect(report.reload.event).to eq(source_event)
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

  describe "#approve" do
    it "approves all pending expenses and requests reimbursement" do
      creator = create(:user)
      event = create(:event)
      approver = create(:user)
      create(:organizer_position, user: approver, event:)
      report = create(:reimbursement_report, user: creator, event:, aasm_state: :submitted, currency: "EUR")
      expense_one = create(:reimbursement_expense, report:, value: 10.00)
      expense_two = create(:reimbursement_expense, report:, value: 20.00)

      expect(report.team_review_required?).to be(true)
      expect(OrganizerPosition.where(user: creator, event:).exists?).to be(false)

      create_session(approver, verified: true)

      post(:approve, params: { report_id: report.id })

      expect(response).to redirect_to(reimbursement_report_path(report))
      expect(expense_one.reload.approved?).to be(true)
      expect(expense_one.approved_by_id).to eq(approver.id)
      expect(expense_two.reload.approved?).to be(true)
      expect(expense_two.approved_by_id).to eq(approver.id)
      expect(report.reload.aasm_state).to eq("reimbursement_requested")
      expect(flash[:success]).to eq("All expenses have been approved and the reimbursement has been requested; the HCB team will review the request promptly.")
    end

    it "rejects the report creator" do
      creator = create(:user)
      event = create(:event)
      report = create(:reimbursement_report, user: creator, event:, aasm_state: :submitted, currency: "EUR")
      create(:reimbursement_expense, report:, value: 10.00)

      create_session(creator, verified: true)

      post(:approve, params: { report_id: report.id })

      expect(flash[:error]).to match(/not authorized/i)
      expect(report.reload.aasm_state).to eq("submitted")
    end

    it "keeps approved expenses when the reimbursement guard fails" do
      creator = create(:user)
      event = create(:event)
      approver = create(:user)
      create(:organizer_position, user: approver, event:)
      report = create(:reimbursement_report, user: creator, event:, aasm_state: :submitted, currency: "USD")
      expense = create(:reimbursement_expense, report:, value: 10.00)

      create_session(approver, verified: true)

      post(:approve, params: { report_id: report.id })

      expect(expense.reload.approved?).to be(true)
      expect(report.reload.aasm_state).to eq("submitted")
      expect(flash[:error]).to be_present
    end
  end

  describe "#destroy" do
    it "lets an external contributor delete their own draft report" do
      user = create(:user)
      event = create(:event)
      report = create(:reimbursement_report, user:, event:, aasm_state: :draft)

      create_session(user, verified: true)

      delete(:destroy, params: { id: report.id })

      expect(Reimbursement::Report.find_by(id: report.id)).to be_nil
      expect(response).to redirect_to(my_reimbursements_path)
    end

    it "does not let an external contributor delete a report once it is submitted" do
      user = create(:user)
      report = create(:reimbursement_report, user:, event: create(:event), aasm_state: :submitted)

      create_session(user, verified: true)

      delete(:destroy, params: { id: report.id })

      expect(flash[:error]).to match(/not authorized/i)
      expect(report.reload).to be_present
    end

    it "does not let a stranger delete someone else's draft report" do
      report = create(:reimbursement_report, user: create(:user), event: create(:event), aasm_state: :draft)
      stranger = create(:user)

      create_session(stranger, verified: true)

      delete(:destroy, params: { id: report.id })

      expect(flash[:error]).to match(/not authorized/i)
      expect(report.reload).to be_present
    end
  end

  describe "#show" do
    render_views

    context "when the viewer is an auditor" do
      it "renders the event's mission statement" do
        admin = create(:user, :make_admin)
        event = create(:event, description: "Audit-target mission statement")
        report = create(:reimbursement_report, user: admin, event:)

        create_session(admin, verified: true)

        get(:show, params: { id: report.id })

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Audit-target mission statement")
      end

      it "renders without error for a draft report with no event" do
        admin = create(:user, :make_admin)
        user = create(:user)
        report = create(:reimbursement_report, user:, event: nil)

        create_session(admin, verified: true)

        get(:show, params: { id: report.id })

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Mission statement")
      end
    end

    context "when the viewer is a report creator who is not an auditor" do
      it "does not render the mission statement" do
        user = create(:user)
        event = create(:event, description: "Non-auditor mission statement")
        report = create(:reimbursement_report, user:, event:)

        create_session(user, verified: true)

        get(:show, params: { id: report.id })

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Mission statement")
        expect(response.body).not_to include("Non-auditor mission statement")
      end
    end
  end
end
