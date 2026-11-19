# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::ReportsController do
  include SessionSupport

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

    it "asks submitters for a reviewer based on the organization's setting" do
      event = create(:event)
      member = create(:user)
      create(:organizer_position, user: member, event:, role: :member)
      report = create(:reimbursement_report, user: member, event:)
      create_session(member, verified: true)

      reviewer_selects = lambda do
        get(:show, params: { id: report.id })
        Nokogiri::HTML5(response.body).css('select[name="reviewer_id"]')
      end

      expect(reviewer_selects.call).to be_empty

      event.update!(reimbursement_reviewer_selection: :optional)
      selects = reviewer_selects.call
      expect(selects).not_to be_empty
      expect(selects.map { |select| select["required"] }).to all(be_nil)
      expect(selects.map { |select| select.at_css("option").text }).to all(eq("No preference"))

      event.update!(reimbursement_reviewer_selection: :required)
      selects = reviewer_selects.call
      expect(selects).not_to be_empty
      expect(selects.map { |select| select["required"] }).to all(eq("required"))
    end

    it "never asks card grant submitters for a reviewer" do
      event = create(:event, :card_grant_event, :with_positive_balance)
      member = create(:user)
      create(:organizer_position, user: member, event:, role: :member)
      card_grant = create(:card_grant, event:, user: member)
      report = create(:reimbursement_report, user: member, event:, card_grant:)
      create_session(member, verified: true)

      event.update!(reimbursement_reviewer_selection: :optional)
      get(:show, params: { id: report.id })
      body = Nokogiri::HTML5(response.body)
      expect(body.css('select[name="reviewer_id"]')).to be_empty
      expect(body.css('select[name="reimbursement_report[reviewer_id]"]')).not_to be_empty

      event.update!(reimbursement_reviewer_selection: :required)
      get(:show, params: { id: report.id })
      expect(Nokogiri::HTML5(response.body).css('select[name="reviewer_id"]')).to be_empty
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

  describe "#edit organization and delete controls" do
    render_views

    def event_options
      Nokogiri::HTML5(response.body).css("select[name='reimbursement_report[event_id]'] option").map(&:text).reject(&:blank?)
    end

    def delete_button?
      Nokogiri::HTML5(response.body).css("button, input[type=submit]").any? { |button| (button.text.presence || button["value"]).to_s.include?("Delete report") }
    end

    it "only lists organizations the manager could move the report to" do
      manager = create(:user)
      event = create(:event, name: "Current Org")
      managed = create(:event, name: "Managed Org")
      member_only = create(:event, name: "Member Org")
      create(:organizer_position, user: manager, event:, role: :manager)
      create(:organizer_position, user: manager, event: managed, role: :manager)
      create(:organizer_position, user: manager, event: member_only, role: :member)
      report = create(:reimbursement_report, user: create(:user), event:)
      create_session(manager, verified: true)

      get(:edit, params: { id: report.id })

      expect(response).to have_http_status(:ok)
      expect(event_options).to contain_exactly("Current Org", "Managed Org")
    end

    it "offers the creator Delete report on a draft" do
      member = create(:user)
      event = create(:event)
      create(:organizer_position, user: member, event:, role: :member)
      report = create(:reimbursement_report, user: member, event:)
      create_session(member, verified: true)

      get(:edit, params: { id: report.id })

      expect(delete_button?).to eq(true)
    end

    it "does not offer a manager Delete report once the report is submitted" do
      manager = create(:user)
      event = create(:event)
      create(:organizer_position, user: manager, event:, role: :manager)
      report = create(:reimbursement_report, user: create(:user), event:)
      report.update_columns(aasm_state: "submitted")
      create_session(manager, verified: true)

      get(:edit, params: { id: report.id })

      expect(response).to have_http_status(:ok)
      expect(delete_button?).to eq(false)
    end
  end

  describe "#show expense move form" do
    render_views

    it "only offers new reports on organizations the viewer can create them for" do
      manager = create(:user)
      event = create(:event, name: "Current Org")
      managed = create(:event, name: "Managed Org")
      member_only = create(:event, name: "Member Org")
      create(:organizer_position, user: manager, event:, role: :manager)
      create(:organizer_position, user: manager, event: managed, role: :manager)
      create(:organizer_position, user: manager, event: member_only, role: :member)
      report = create(:reimbursement_report, user: manager, event:)
      expense = create(:reimbursement_expense, report:)
      create_session(manager, verified: true)

      get(:show, params: { id: report.id })

      expect(response).to have_http_status(:ok)
      options = Nokogiri::HTML5(response.body).css("#move_#{expense.id} select[name='reimbursement_expense[event_id]'] option").map(&:text).reject(&:blank?)
      expect(options).to include("Current Org", "Managed Org")
      expect(options).not_to include("Member Org")
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

    context "when the report has no event yet" do
      # Reports created by email, SMS or Discord start without an event.
      # ReportPolicy#change_event? lets the creator place such a report on
      # an event, under the same rules as ReportPolicy#create?.

      it "lets the creator place it on an event they are a member of" do
        creator = create(:user)
        own_event = create(:event)
        create(:organizer_position, user: creator, event: own_event, role: :member)
        report = create(:reimbursement_report, user: creator, event: nil)

        create_session(creator, verified: true)

        patch(:update, params: {
                id: report.id,
                reimbursement_report: { event_id: own_event.id }
              })

        expect(flash[:success]).to be_present
        expect(report.reload.event).to eq(own_event)
      end

      it "lets the creator place it on an event whose public reimbursement page is enabled" do
        creator = create(:user)
        open_event = create(:event, public_reimbursement_page_enabled: true)
        report = create(:reimbursement_report, user: creator, event: nil)

        create_session(creator, verified: true)

        patch(:update, params: {
                id: report.id,
                reimbursement_report: { event_id: open_event.id }
              })

        expect(flash[:success]).to be_present
        expect(report.reload.event).to eq(open_event)
      end

      it "blocks placing it on an event the creator is not part of" do
        creator = create(:user)
        victim_event = create(:event, public_reimbursement_page_enabled: false)
        report = create(:reimbursement_report, user: creator, event: nil)

        create_session(creator, verified: true)

        patch(:update, params: {
                id: report.id,
                reimbursement_report: { event_id: victim_event.id }
              })

        expect(flash[:error]).to match(/not authorized/i)
        expect(report.reload.event).to be_nil
      end

      it "blocks placing it on a demo-mode event" do
        creator = create(:user)
        demo_event = create(:event, :demo_mode)
        report = create(:reimbursement_report, user: creator, event: nil)

        create_session(creator, verified: true)

        patch(:update, params: {
                id: report.id,
                reimbursement_report: { event_id: demo_event.id }
              })

        expect(flash[:error]).to match(/not authorized/i)
        expect(report.reload.event).to be_nil
      end

      it "blocks a nonexistent event id without raising" do
        creator = create(:user)
        report = create(:reimbursement_report, user: creator, event: nil)

        create_session(creator, verified: true)

        patch(:update, params: {
                id: report.id,
                reimbursement_report: { event_id: 999_999_999 }
              })

        expect(flash[:error]).to match(/not authorized/i)
        expect(report.reload.event).to be_nil
      end

      it "keeps a second event change manager-only" do
        creator = create(:user)
        own_event = create(:event)
        create(:organizer_position, user: creator, event: own_event, role: :member)
        other_event = create(:event)
        create(:organizer_position, user: creator, event: other_event, role: :member)
        report = create(:reimbursement_report, user: creator, event: nil)
        report.update!(event: own_event)

        create_session(creator, verified: true)

        patch(:update, params: {
                id: report.id,
                reimbursement_report: { event_id: other_event.id }
              })

        expect(flash[:error]).to match(/not authorized/i)
        expect(report.reload.event).to eq(own_event)
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

      it "lets a card grant recipient assign a reviewer from the settings menu" do
        event = create(:event, :card_grant_event, :with_positive_balance)
        recipient = create(:user)
        reviewer = create(:user)
        create(:organizer_position, user: reviewer, event:)
        card_grant = create(:card_grant, event:, user: recipient)
        report = create(:reimbursement_report, user: recipient, event:, card_grant:)

        event.update!(reimbursement_reviewer_selection: :optional)
        create_session(recipient, verified: true)

        patch(:update, params: {
                id: report.id,
                reimbursement_report: { report_name: report.name, reviewer_id: reviewer.id }
              })

        expect(report.reload.reviewer_id).to eq(reviewer.id)
      end

      it "rejects an ineligible reviewer from a card grant recipient" do
        event = create(:event, :card_grant_event, :with_positive_balance)
        recipient = create(:user)
        outsider = create(:user)
        card_grant = create(:card_grant, event:, user: recipient)
        report = create(:reimbursement_report, user: recipient, event:, card_grant:)

        event.update!(reimbursement_reviewer_selection: :optional)
        create_session(recipient, verified: true)

        patch(:update, params: {
                id: report.id,
                reimbursement_report: { report_name: report.name, reviewer_id: outsider.id }
              })

        expect(response).to have_http_status(:unprocessable_content)
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

  describe "#submit" do
    it "lets submitters pick any manager, including ones who opted out of reviewing" do
      event = create(:event, reimbursement_reviewer_selection: :required)
      member = create(:user)
      other_member = create(:user)
      opted_out = create(:user)
      create(:organizer_position, user: member, event:, role: :member)
      create(:organizer_position, user: other_member, event:, role: :member)
      create(:organizer_position, user: opted_out, event:, role: :manager).reimbursement_reviewer_opt_ins.destroy_all
      report = create(:reimbursement_report, user: member, event:)

      create_session(member, verified: true)

      post(:submit, params: { report_id: report.id, reviewer_id: other_member.public_id })

      expect(flash[:error]).to eq("The selected reviewer is not eligible for this report.")
      expect(report.reload.reviewer).to be_nil

      post(:submit, params: { report_id: report.id, reviewer_id: opted_out.public_id })

      expect(flash[:error]).not_to eq("The selected reviewer is not eligible for this report.")
    end

    it "lets submitters skip picking a reviewer when it's optional" do
      event = create(:event, reimbursement_reviewer_selection: :optional)
      member = create(:user)
      create(:organizer_position, user: member, event:, role: :member)
      report = create(:reimbursement_report, user: member, event:)

      create_session(member, verified: true)

      post(:submit, params: { report_id: report.id, reviewer_id: "" })

      expect(response).to redirect_to(reimbursement_report_path(report))
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

    context "when the viewer is the creator of a report with no event" do
      it "renders the edit icon and leaves the organization select enabled" do
        creator = create(:user)
        report = create(:reimbursement_report, user: creator, event: nil)

        create_session(creator, verified: true)

        get(:show, params: { id: report.id })
        select_tag = response.body[/<select[^>]*name="reimbursement_report\[event_id\]"[^>]*>/]

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Edit this report&#39;s properties.")
        expect(select_tag).to be_present
        expect(select_tag).not_to include("disabled")
      end
    end

  end

  describe "#update maximum amount and reviewer" do
    let(:event) { create(:event, :card_grant_event, :with_positive_balance) }
    let(:reviewer) { create(:user).tap { |user| create(:organizer_position, user:, event:, role: :manager) } }

    def submit_maximum_amount_and_reviewer(actor, report)
      create_session(actor, verified: true)

      patch(:update, params: {
              id: report.id,
              reimbursement_report: { report_name: "Renamed", maximum_amount: "250.00", reviewer_id: reviewer.id }
            })

      report.reload
    end

    def card_grant_report(recipient, aasm_state: :draft)
      event.update!(reimbursement_reviewer_selection: :optional)
      card_grant = create(:card_grant, event:, user: recipient)
      create(:reimbursement_report, user: recipient, event:, card_grant:, aasm_state:)
    end

    it "saves both for an admin" do
      report = create(:reimbursement_report, user: create(:user), event:)

      report = submit_maximum_amount_and_reviewer(create(:user, :make_admin), report)

      expect(report.maximum_amount_cents).to eq(250_00)
      expect(report.reviewer_id).to eq(reviewer.id)
    end

    it "saves both for a manager" do
      manager = create(:user)
      create(:organizer_position, user: manager, event:, role: :manager)
      report = create(:reimbursement_report, user: create(:user), event:, aasm_state: :submitted)

      report = submit_maximum_amount_and_reviewer(manager, report)

      expect(report.maximum_amount_cents).to eq(250_00)
      expect(report.reviewer_id).to eq(reviewer.id)
    end

    it "saves both for a manager of the parent organization" do
      parent_manager = create(:user)
      event.update!(parent: create(:event))
      create(:organizer_position, user: parent_manager, event: event.parent, role: :manager)
      report = create(:reimbursement_report, user: create(:user), event:)

      report = submit_maximum_amount_and_reviewer(parent_manager, report)

      expect(report.maximum_amount_cents).to eq(250_00)
      expect(report.reviewer_id).to eq(reviewer.id)
    end

    it "saves only the reviewer for a manager once reimbursement is requested" do
      manager = create(:user)
      create(:organizer_position, user: manager, event:, role: :manager)
      report = create(:reimbursement_report, user: create(:user), event:, aasm_state: :reimbursement_requested)

      report = submit_maximum_amount_and_reviewer(manager, report)

      expect(report.maximum_amount_cents).to be_nil
      expect(report.reviewer_id).to eq(reviewer.id)
    end

    it "saves neither for a member editing their own draft" do
      member = create(:user)
      create(:organizer_position, user: member, event:, role: :member)
      report = create(:reimbursement_report, user: member, event:)

      report = submit_maximum_amount_and_reviewer(member, report)

      expect(report.name).to eq("Renamed")
      expect(report.maximum_amount_cents).to be_nil
      expect(report.reviewer_id).to be_nil
    end

    it "saves neither for a reader editing their own draft" do
      reader = create(:user)
      create(:organizer_position, user: reader, event:, role: :reader)
      report = create(:reimbursement_report, user: reader, event:)

      report = submit_maximum_amount_and_reviewer(reader, report)

      expect(report.name).to eq("Renamed")
      expect(report.maximum_amount_cents).to be_nil
      expect(report.reviewer_id).to be_nil
    end

    it "saves neither for an outside contributor editing their own draft" do
      contributor = create(:user)
      report = create(:reimbursement_report, user: contributor, event:)

      report = submit_maximum_amount_and_reviewer(contributor, report)

      expect(report.name).to eq("Renamed")
      expect(report.maximum_amount_cents).to be_nil
      expect(report.reviewer_id).to be_nil
    end

    it "saves only the reviewer for a card grant recipient editing their own draft" do
      recipient = create(:user)
      create(:organizer_position, user: recipient, event:, role: :member)
      report = card_grant_report(recipient)

      report = submit_maximum_amount_and_reviewer(recipient, report)

      expect(report.maximum_amount_cents).to be_nil
      expect(report.reviewer_id).to eq(reviewer.id)
    end

    it "saves neither for a card grant recipient once reimbursement is requested" do
      recipient = create(:user)
      report = card_grant_report(recipient, aasm_state: :reimbursement_requested)

      report = submit_maximum_amount_and_reviewer(recipient, report)

      expect(report.name).to eq("Renamed")
      expect(report.maximum_amount_cents).to be_nil
      expect(report.reviewer_id).to be_nil
    end

    {
      "an auditor"  => ->(_event) { create(:user, :make_auditor) },
      "a member"    => ->(event) { create(:user).tap { |user| create(:organizer_position, user:, event:, role: :member) } },
      "an outsider" => ->(_event) { create(:user) },
    }.each do |actor_description, build_actor|
      it "does not let #{actor_description} update someone else's report" do
        report = create(:reimbursement_report, user: create(:user), event:)

        report = submit_maximum_amount_and_reviewer(instance_exec(event, &build_actor), report)

        expect(flash[:error]).to match(/not authorized/i)
        expect(report.name).not_to eq("Renamed")
        expect(report.maximum_amount_cents).to be_nil
        expect(report.reviewer_id).to be_nil
      end
    end
  end

  describe "maximum amount and reviewer fields on the edit form" do
    render_views

    let(:event) { create(:event, :card_grant_event, :with_positive_balance) }

    def maximum_amount_field?
      Nokogiri::HTML5(response.body).at_css("input[name='reimbursement_report[maximum_amount]']").present?
    end

    def reviewer_options
      Nokogiri::HTML5(response.body).css("select[name='reimbursement_report[reviewer_id]'] option").map { |option| [option.text, option["value"]] }
    end

    def reviewer_option_ids
      reviewer_options.map(&:last).compact_blank.map(&:to_i)
    end

    it "hides both from a member editing their own draft" do
      member = create(:user)
      create(:organizer_position, user: member, event:, role: :member)
      report = create(:reimbursement_report, user: member, event:)
      create_session(member, verified: true)

      get(:edit, params: { id: report.id })

      expect(response).to have_http_status(:ok)
      expect(maximum_amount_field?).to eq(false)
      expect(reviewer_options).to be_empty
    end

    it "hides both from an auditor viewing the report" do
      report = create(:reimbursement_report, user: create(:user), event:)
      create_session(create(:user, :make_auditor), verified: true)

      get(:show, params: { id: report.id })

      expect(response).to have_http_status(:ok)
      expect(maximum_amount_field?).to eq(false)
      expect(reviewer_options).to be_empty
    end

    it "shows both to a manager, offering every eligible reviewer" do
      manager = create(:user)
      create(:organizer_position, user: manager, event:, role: :manager)
      event.update!(parent: create(:event))
      parent_manager = create(:user)
      create(:organizer_position, user: parent_manager, event: event.parent, role: :manager)
      create(:organizer_position, user: create(:user), event:, role: :member)
      report = create(:reimbursement_report, user: create(:user), event:)
      create_session(manager, verified: true)

      get(:edit, params: { id: report.id })

      expect(response).to have_http_status(:ok)
      expect(maximum_amount_field?).to eq(true)
      expect(reviewer_options.first).to eq(["Anyone", ""])
      expect(reviewer_option_ids).to contain_exactly(manager.id, parent_manager.id)
    end

    it "shows both to an admin" do
      reviewer = create(:user)
      create(:organizer_position, user: reviewer, event:, role: :manager)
      report = create(:reimbursement_report, user: create(:user), event:)
      create_session(create(:user, :make_admin), verified: true)

      get(:edit, params: { id: report.id })

      expect(response).to have_http_status(:ok)
      expect(maximum_amount_field?).to eq(true)
      expect(reviewer_option_ids).to contain_exactly(reviewer.id)
    end

    it "shows a card grant recipient who is also a member only the reviewer field, with the eligible reviewers" do
      recipient = create(:user)
      create(:organizer_position, user: recipient, event:, role: :member)
      reviewer = create(:user)
      create(:organizer_position, user: reviewer, event:, role: :manager)
      event.update!(reimbursement_reviewer_selection: :optional)
      card_grant = create(:card_grant, event:, user: recipient)
      report = create(:reimbursement_report, user: recipient, event:, card_grant:)
      create_session(recipient, verified: true)

      get(:edit, params: { id: report.id })

      expect(response).to have_http_status(:ok)
      expect(maximum_amount_field?).to eq(false)
      expect(reviewer_options.first).to eq(["No preference", ""])
      expect(reviewer_option_ids).to contain_exactly(reviewer.id)
    end
  end
end
