# frozen_string_literal: true

require "rails_helper"

RSpec.describe LegalEntitiesController do
  include SessionSupport

  let(:user) { create(:user) }
  let(:legal_entity) { create(:legal_entity, :business, name: "Acme", tin_hash: "abc") }

  before do
    legal_entity.users << user
    create_session(user, verified: true)
  end

  describe "POST #create_from_tax_form" do
    let!(:tax_form) do
      create(:tax_form, :completed, legal_entity:, tin_hash: "def", entity_type: :business)
    end

    it "creates a legal entity for the new TIN" do
      post :create_from_tax_form, params: {
        new_tax_form_id: tax_form.hashid,
        old_le_id: legal_entity.hashid,
        name: "Acme Subsidiary"
      }

      new_le = LegalEntity.find_by(name: "Acme Subsidiary")

      expect(new_le).to be_present
      expect(new_le.tin_hash).to eq("def")
      expect(tax_form.reload.legal_entity).to eq(new_le)
      expect(response).to redirect_to(legal_entity_path(new_le))
    end

    it "moves payments that have not been sent yet onto the new legal entity" do
      payee = create(:payee, legal_entity:)
      pending = create(:payment, payee:, aasm_state: :pending_legal_entity)

      post :create_from_tax_form, params: {
        new_tax_form_id: tax_form.hashid,
        old_le_id: legal_entity.hashid,
        name: "Acme Subsidiary"
      }

      new_le = LegalEntity.find_by(name: "Acme Subsidiary")

      expect(pending.reload.payee.legal_entity).to eq(new_le)
    end

    it "refuses to move a legal entity the user does not belong to" do
      someone_else = create(:legal_entity, :business, tin_hash: "xyz")
      their_payee = create(:payee, legal_entity: someone_else)
      their_payment = create(:payment, payee: their_payee, aasm_state: :pending_legal_entity)

      post :create_from_tax_form, params: {
        new_tax_form_id: tax_form.hashid,
        old_le_id: someone_else.hashid,
        name: "Stolen"
      }

      expect(LegalEntity.find_by(name: "Stolen")).to be_nil
      expect(their_payment.reload.payee).to eq(their_payee)
    end

    it "refuses a tax form that has not finished processing" do
      unfinished = create(:tax_form, :sent, legal_entity:, tin_hash: nil)

      post :create_from_tax_form, params: {
        new_tax_form_id: unfinished.hashid,
        old_le_id: legal_entity.hashid,
        name: "Too Early"
      }

      expect(LegalEntity.find_by(name: "Too Early")).to be_nil
      expect(flash[:error]).to be_present
    end
  end

  describe "POST #replace" do
    let!(:old_form) do
      create(:tax_form, :completed, legal_entity:, tin_hash: "abc", entity_type: :business)
    end
    let!(:new_form) do
      create(:tax_form, :completed, legal_entity:, tin_hash: "def", entity_type: :business)
    end

    it "archives the old legal entity and carries the payout methods across" do
      payout_method = legal_entity.payout_methods.create!(
        details: LegalEntity::PayoutMethod::AchTransfer.create!(account_number: "12345678", routing_number: "021000021"),
        default: true
      )

      post :replace, params: { id: legal_entity.hashid, new_tax_form_id: new_form.hashid }

      new_le = LegalEntity.where.not(id: legal_entity.id).order(:id).last

      expect(legal_entity.reload).to be_archived
      expect(new_le.tin_hash).to eq("def")
      expect(payout_method.reload.legal_entity).to eq(new_le)
      expect(response).to redirect_to(legal_entity_path(new_le))
    end

    it "archives every payee of the archived entity so no organization can pay it again" do
      payee = create(:payee, legal_entity:)

      post :replace, params: { id: legal_entity.hashid, new_tax_form_id: new_form.hashid }

      expect(payee.reload).to be_archived
    end

    it "refuses a tax form for a different kind of entity" do
      personal_form = create(:tax_form, :completed, legal_entity:, tin_hash: "ghi", entity_type: :person)

      post :replace, params: { id: legal_entity.hashid, new_tax_form_id: personal_form.hashid }

      expect(legal_entity.reload).not_to be_archived
      expect(flash[:error]).to be_present
      expect(response).to redirect_to(legal_entity_path(legal_entity))
    end
  end
end
