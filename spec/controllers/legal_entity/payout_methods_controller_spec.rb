# frozen_string_literal: true

require "rails_helper"

RSpec.describe LegalEntity::PayoutMethodsController do
  include SessionSupport

  let(:user) { create(:user) }
  let(:legal_entity) { user.personal_legal_entity }

  def ach(account: "12345678")
    LegalEntity::PayoutMethod::AchTransfer.new(account_number: account, routing_number: "021000021")
  end

  before do
    create_session(user, verified: true)
  end

  describe "#create" do
    it "adds a payout method" do
      expect do
        post(:create, params: {
               user: {
                 payout_method_type: "LegalEntity::PayoutMethod::AchTransfer",
                 payout_method_ach_transfer: { account_number: "12345678", routing_number: "021000021" }
               }
             })
      end.to change { legal_entity.reload.payout_methods.count }.by(1)
    end

    it "stores the user-provided nickname" do
      post(:create, params: {
             user: {
               payout_method_type: "LegalEntity::PayoutMethod::AchTransfer",
               payout_method_name: "My Chase Bank Account",
               payout_method_ach_transfer: { account_number: "12345678", routing_number: "021000021" }
             }
           })

      expect(legal_entity.reload.payout_methods.last.name).to eq("My Chase Bank Account")
    end

    context "when an admin adds a payout method for another user" do
      let(:admin) { create(:user, :make_admin) }

      before { create_session(admin, verified: true) }

      it "adds the method to the target user's entity, not the admin's" do
        expect do
          post(:create, params: {
                 legal_entity_id: legal_entity.id,
                 user: {
                   payout_method_type: "LegalEntity::PayoutMethod::AchTransfer",
                   payout_method_ach_transfer: { account_number: "12345678", routing_number: "021000021" }
                 }
               })
        end.to change { legal_entity.reload.payout_methods.count }.by(1)

        expect(admin.personal_legal_entity.reload.payout_methods.count).to eq(0)
      end
    end
  end

  describe "#update" do
    it "creates a new record and archives the old one instead of mutating in place" do
      pm = legal_entity.payout_methods.create!(default: true, details: ach)

      patch(:update, params: {
              id: pm.id,
              user: { payout_method_ach_transfer: { account_number: "99999999", routing_number: "021000021" } }
            })

      # Old record is archived (not destroyed) and disappears from the active list.
      expect(pm.reload.archived).to be(true)
      expect(legal_entity.payout_methods.unarchived).not_to include(pm)

      new_pm = legal_entity.reload.default_payout_method
      expect(new_pm).not_to eq(pm)
      expect(new_pm.details.account_number).to eq("99999999")
    end

    it "updates only the nickname when ACH numbers come back masked, keeping the real values" do
      pm = legal_entity.payout_methods.create!(default: true, details: ach(account: "12345678"), name: "Old name")

      patch(:update, params: {
              id: pm.id,
              user: {
                payout_method_name: "My Chase Bank Account",
                payout_method_ach_transfer: { account_number: "••••5678", routing_number: "•••••0021" }
              }
            })

      new_pm = legal_entity.reload.default_payout_method
      expect(new_pm.name).to eq("My Chase Bank Account")
      expect(new_pm.details.account_number).to eq("12345678")
      expect(new_pm.details.routing_number).to eq("021000021")
    end

    it "blocks editing a method while a report using it is in-flight" do
      pm = legal_entity.payout_methods.create!(default: true, details: ach)
      create(:reimbursement_report, user:, event: create(:event), aasm_state: :submitted, legal_entity_payout_method: pm)

      patch(:update, params: {
              id: pm.id,
              user: { payout_method_ach_transfer: { account_number: "99999999", routing_number: "021000021" } }
            })

      expect(flash[:error]).to match(/being processed/i)
      expect(LegalEntity::PayoutMethod.exists?(pm.id)).to be(true)
      expect(pm.reload.details.account_number).to eq("12345678")
    end
  end

  describe "#archive" do
    it "blocks removing a method while a report using it is in-flight" do
      pm = legal_entity.payout_methods.create!(default: true, details: ach)
      create(:reimbursement_report, user:, event: create(:event), aasm_state: :reimbursement_requested, legal_entity_payout_method: pm)

      delete(:archive, params: { id: pm.id })

      expect(flash[:error]).to match(/being processed/i)
      expect(LegalEntity::PayoutMethod.exists?(pm.id)).to be(true)
    end

    it "does not allow removing the default method while other methods remain" do
      default_pm = legal_entity.payout_methods.create!(default: true, details: ach)
      legal_entity.payout_methods.create!(default: false, details: ach(account: "99999999"))

      delete(:archive, params: { id: default_pm.id })

      expect(flash[:error]).to match(/default/i)
      expect(default_pm.reload.archived).to be(false)
      expect(default_pm).to be_default
    end

    it "removes the default method when it is the only unarchived method" do
      default_pm = legal_entity.payout_methods.create!(default: true, details: ach)

      delete(:archive, params: { id: default_pm.id })

      expect(flash[:success]).to match(/removed/i)
      expect(default_pm.reload.archived).to be(true)
      expect(default_pm).not_to be_default
    end

    it "unpins a draft report from the sole removed method" do
      default_pm = legal_entity.payout_methods.create!(default: true, details: ach)
      report = create(:reimbursement_report, user:, event: create(:event), aasm_state: :draft, legal_entity_payout_method: default_pm)

      delete(:archive, params: { id: default_pm.id })

      expect(report.reload.legal_entity_payout_method).to be_nil
    end

    it "archives a removed method instead of destroying it" do
      legal_entity.payout_methods.create!(default: true, details: ach)
      other_pm = legal_entity.payout_methods.create!(default: false, details: ach(account: "99999999"))

      delete(:archive, params: { id: other_pm.id })

      expect(LegalEntity::PayoutMethod.exists?(other_pm.id)).to be(true)
      expect(other_pm.reload.archived).to be(true)
      expect(legal_entity.payout_methods.unarchived).not_to include(other_pm)
    end

    it "reassigns a draft report to the default when its (non-default) method is removed" do
      default_pm = legal_entity.payout_methods.create!(default: true, details: ach)
      other_pm = legal_entity.payout_methods.create!(default: false, details: ach(account: "99999999"))
      report = create(:reimbursement_report, user:, event: create(:event), aasm_state: :draft, legal_entity_payout_method: other_pm)

      delete(:archive, params: { id: other_pm.id })

      expect(report.reload.legal_entity_payout_method).to eq(default_pm)
    end

    it "can't act on an already-archived method" do
      legal_entity.payout_methods.create!(default: true, details: ach)
      archived = legal_entity.payout_methods.create!(default: false, archived: true, details: ach(account: "99999999"))

      delete(:archive, params: { id: archived.id })

      expect(flash[:error]).to match(/not found/i)
    end
  end

  describe "#set_default" do
    it "is allowed even when another method is locked by an in-flight report" do
      locked_pm = legal_entity.payout_methods.create!(default: true, details: ach)
      create(:reimbursement_report, user:, event: create(:event), aasm_state: :submitted, legal_entity_payout_method: locked_pm)
      other_pm = legal_entity.payout_methods.create!(default: false, details: ach(account: "99999999"))

      patch(:set_default, params: { id: other_pm.id })

      expect(other_pm.reload).to be_default
      expect(locked_pm.reload).not_to be_default
    end
  end

  describe "#complete_details" do
    let!(:payout_method) do
      legal_entity.payout_methods.create!(default: true, details: create(:wise_transfer_payout_method_details)).tap do |pm|
        pm.details.update!(recipient_birthday: nil)
      end
    end

    it "fills in the missing date of birth even while a report locks the method" do
      create(:reimbursement_report, user:, event: create(:event), aasm_state: :reimbursement_requested, legal_entity_payout_method: payout_method)

      patch(:complete_details, params: { id: payout_method.id, payout_method_details: { recipient_birthday: "01/15/1990" } })

      expect(flash[:success]).to eq("Payout method updated.")
      expect(payout_method.reload).to be_ready_for_payout
    end

    it "does not change fields that weren't missing" do
      patch(:complete_details, params: { id: payout_method.id, payout_method_details: { recipient_birthday: "01/15/1990", address_line1: "999 Elsewhere" } })

      expect(payout_method.details.reload.address_line1).to eq("123 Main St")
    end

    it "shows an error for an invalid date" do
      patch(:complete_details, params: { id: payout_method.id, payout_method_details: { recipient_birthday: "13/45/1990" } })

      expect(flash[:error]).to include("MM/DD/YYYY")
      expect(payout_method.reload).to be_incomplete
    end

    it "doesn't let another user complete the method" do
      create_session(create(:user), verified: true)

      patch(:complete_details, params: { id: payout_method.id, payout_method_details: { recipient_birthday: "01/15/1990" } })

      expect(payout_method.reload).to be_incomplete
    end
  end
end
