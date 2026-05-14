# frozen_string_literal: true

require "rails_helper"

RSpec.describe IncreaseChecksController do
  include SessionSupport

  describe "edit" do
    it "allows an admin to edit a pending check" do
      admin = create(:user, :make_admin)
      check = create(:increase_check)

      create_session(admin, verified: true)

      get :edit, params: { id: check }

      expect(response).to have_http_status(:ok)
    end

    it "does not allow a non-admin to edit a check" do
      user = create(:user)
      check = create(:increase_check)

      create_session(user, verified: true)

      get :edit, params: { id: check }

      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to be_present
    end

    it "does not allow editing an approved check" do
      admin = create(:user, :make_admin)
      check = create(:increase_check, :approved)

      create_session(admin, verified: true)

      get :edit, params: { id: check }

      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to be_present
    end
  end

  describe "update" do
    def update_params
      {
        memo: "Updated memo",
        amount: "200.00",
        payment_for: "New supplies",
        recipient_name: "Jane Smith",
        recipient_email: "jane@example.com",
        address_line1: "2 New Street",
        address_city: "Oakland",
        address_state: "CA",
        address_zip: "94601",
      }
    end

    it "updates all editable fields and redirects to the admin process page" do
      admin = create(:user, :make_admin)
      check = create(:increase_check)

      create_session(admin, verified: true)

      patch :update, params: { id: check, increase_check: update_params }

      expect(response).to redirect_to(increase_check_process_admin_path(check))
      expect(flash[:success]).to eq("Check has been updated.")

      check.reload
      expect(check.memo).to eq("Updated memo")
      expect(check.amount).to eq(200_00)
      expect(check.payment_for).to eq("New supplies")
      expect(check.recipient_name).to eq("Jane Smith")
      expect(check.recipient_email).to eq("jane@example.com")
      expect(check.address_line1).to eq("2 New Street")
      expect(check.address_city).to eq("Oakland")
      expect(check.address_state).to eq("CA")
      expect(check.address_zip).to eq("94601")
    end

    it "syncs the canonical_pending_transaction when amount changes" do
      admin = create(:user, :make_admin)
      check = create(:increase_check, amount: 10_000)

      create_session(admin, verified: true)

      patch :update, params: { id: check, increase_check: update_params }

      expect(check.canonical_pending_transaction.reload.amount_cents).to eq(-200_00)
    end

    it "redirects to the edit page with an error flash on validation failure" do
      admin = create(:user, :make_admin)
      check = create(:increase_check)

      create_session(admin, verified: true)

      patch :update, params: { id: check, increase_check: update_params.merge(memo: "x" * 41) }

      expect(response).to redirect_to(edit_increase_check_path(check))
      expect(flash[:error]).to be_present
      expect(check.reload.memo).not_to eq("x" * 41)
    end

    it "does not allow a non-admin to update a check" do
      user = create(:user)
      check = create(:increase_check)
      original_memo = check.memo

      create_session(user, verified: true)

      patch :update, params: { id: check, increase_check: update_params }

      expect(response).to redirect_to(root_path)
      expect(check.reload.memo).to eq(original_memo)
    end

    it "does not allow updating an approved check" do
      admin = create(:user, :make_admin)
      check = create(:increase_check, :approved)
      original_memo = check.memo

      create_session(admin, verified: true)

      patch :update, params: { id: check, increase_check: update_params }

      expect(response).to redirect_to(root_path)
      expect(check.reload.memo).to eq(original_memo)
    end
  end
end
