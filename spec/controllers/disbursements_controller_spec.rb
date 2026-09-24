# frozen_string_literal: true

require "rails_helper"

RSpec.describe DisbursementsController do
  include SessionSupport
  render_views

  describe "#create" do
    it "creates a disbursement" do
      sender = create(:user)
      source_event = create(:event, :with_positive_balance)
      create(:organizer_position, user: sender, event: source_event)

      destination_event = create(:event)
      create(:organizer_position, user: sender, event: destination_event)

      create_session(sender, verified: true)

      expect do
        post(
          :create,
          params: {
            disbursement: {
              name: "Boba Drops",
              source_event_id: source_event.public_id,
              event_id: destination_event.public_id,
              amount: "123.45"
            }
          }
        )
      end.to change(Disbursement, :count).by(1)

      expect(flash[:success]).to eq("Transfer successfully requested.")
      expect(response).to redirect_to(event_transfers_path(source_event))

      disbursement = Disbursement.last
      expect(disbursement.name).to eq("Boba Drops")
      expect(disbursement.amount).to eq(123_45)
      expect(disbursement.source_event).to eq(source_event)
      expect(disbursement.destination_event).to eq(destination_event)
    end

    it "allows transaction categories to be set by admins" do
      sender = create(:user, :make_admin)
      create(:governance_admin_transfer_limit, user: sender)
      source_event = create(:event, :with_positive_balance)
      create(:organizer_position, user: sender, event: source_event)

      destination_event = create(:event)

      create_session(sender, verified: true)

      expect do
        post(
          :create,
          params: {
            disbursement: {
              name: "Boba Drops",
              source_event_id: source_event.public_id,
              event_id: destination_event.public_id,
              amount: "123.45",
              source_transaction_category_slug: "donations",
              destination_transaction_category_slug: "fundraising",
            }
          }
        )
      end.to change(Disbursement, :count).by(1)

      expect(flash[:success]).to eq("Transfer successfully requested.")
      expect(response).to redirect_to(disbursements_admin_index_path)

      disbursement = Disbursement.last
      expect(disbursement.name).to eq("Boba Drops")
      expect(disbursement.amount).to eq(123_45)
      expect(disbursement.source_event).to eq(source_event)
      expect(disbursement.destination_event).to eq(destination_event)
      expect(disbursement.source_transaction_category.slug).to eq("donations")
      expect(disbursement.destination_transaction_category.slug).to eq("fundraising")
    end
  end

  describe "#set_transaction_categories" do
    it "allows categories to be set by admins" do
      admin = create(:user, :make_admin)
      disbursement = create(:disbursement)

      create_session(admin, verified: true)

      post(
        :set_transaction_categories,
        params: {
          disbursement_id: disbursement.id,
          disbursement: {
            source_transaction_category_slug: "donations",
            destination_transaction_category_slug: "fundraising",
          }
        },
        format: :html
      )

      expect(response).to redirect_to(disbursement_path(disbursement))

      disbursement.reload
      expect(disbursement.source_transaction_category.slug).to eq("donations")
      expect(disbursement.destination_transaction_category.slug).to eq("fundraising")
    end

    it "clears the categories if the param is blank" do
      admin = create(:user, :make_admin)
      disbursement = create(
        :disbursement,
        source_transaction_category: TransactionCategory.find_or_create_by!(slug: "donations"),
        destination_transaction_category: TransactionCategory.find_or_create_by!(slug: "fundraising"),
      )

      create_session(admin, verified: true)

      post(
        :set_transaction_categories,
        params: {
          disbursement_id: disbursement.id,
          disbursement: {
            source_transaction_category_slug: "",
            destination_transaction_category_slug: "",
          }
        },
        format: :html
      )

      expect(response).to redirect_to(disbursement_path(disbursement))

      disbursement.reload
      expect(disbursement.source_transaction_category).to be_nil
      expect(disbursement.destination_transaction_category).to be_nil
    end

    it "allows one category to be set without affecting the other" do
      admin = create(:user, :make_admin)
      disbursement = create(
        :disbursement,
        source_transaction_category: TransactionCategory.find_or_create_by!(slug: "donations"),
        destination_transaction_category: TransactionCategory.find_or_create_by!(slug: "fundraising"),
      )

      create_session(admin, verified: true)

      post(
        :set_transaction_categories,
        params: {
          disbursement_id: disbursement.id,
          disbursement: {
            destination_transaction_category_slug: "rent",
          }
        },
        format: :html
      )

      expect(response).to redirect_to(disbursement_path(disbursement))

      disbursement.reload
      expect(disbursement.source_transaction_category.slug).to eq("donations")
      expect(disbursement.destination_transaction_category.slug).to eq("rent")
    end
  end

  describe "#event_search" do
    it "ranks the exact match first even when substring matches would trim it" do
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      create(:event, name: "ysws - aaa")
      create(:event, name: "ysws - bbb")
      create(:event, name: "ysws - ccc")
      exact = create(:event, name: "ysws")

      get(:event_search, params: { q: "ysws" }, format: :json)

      expect(response).to have_http_status(:ok)
      labels = JSON.parse(response.body).map { |o| o["label"] }
      expect(labels.first).to eq("ysws (#{exact.id})")
    end

    it "paginates results without overlap across pages" do
      stub_const("DisbursementsController::PAGE_SIZE", 2)
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      3.times { |i| create(:event, name: "ysws #{i}") }

      get(:event_search, params: { q: "ysws", page: 1 }, format: :json)
      page1 = JSON.parse(response.body).map { |o| o["value"] }
      get(:event_search, params: { q: "ysws", page: 2 }, format: :json)
      page2 = JSON.parse(response.body).map { |o| o["value"] }

      expect(page1.size).to eq(2)
      expect(page2.size).to eq(1)
      expect(page1 & page2).to be_empty
    end

    it "clamps non-positive page numbers to the first page" do
      stub_const("DisbursementsController::PAGE_SIZE", 2)
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      3.times { |i| create(:event, name: "ysws #{i}") }

      get(:event_search, params: { q: "ysws", page: 0 }, format: :json)
      expect(JSON.parse(response.body).size).to eq(2)
    end
  end

  describe "#show" do
    it "renders and resolves the comment thread HcbCode via the outgoing hcb_code" do
      auditor = create(:user, :make_auditor)
      disbursement = create(:disbursement)

      create_session(auditor, verified: true)

      get(:show, params: { id: disbursement.id })

      expect(response).to have_http_status(:ok)
      # The show action find-or-creates the comment thread's HcbCode from the
      # outgoing hcb_code (the legacy `hcb_code` alias was removed).
      expect(HcbCode.exists?(hcb_code: disbursement.outgoing_hcb_code)).to be(true)
    end
  end
end
