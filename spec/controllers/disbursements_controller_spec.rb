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

    it "accepts numeric event ids from the combobox form" do
      sender = create(:user)
      source_event = create(:event, :with_positive_balance)
      create(:organizer_position, user: sender, event: source_event)

      destination_event = create(:event)
      create(:organizer_position, user: sender, event: destination_event)

      sign_in(sender)

      expect do
        post(
          :create,
          params: {
            disbursement: {
              name: "Boba Drops",
              source_event_id: source_event.id,
              event_id: destination_event.id,
              amount: "123.45"
            }
          }
        )
      end.to change(Disbursement, :count).by(1)

      expect(response).to redirect_to(event_transfers_path(source_event))

      disbursement = Disbursement.last
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

  describe "#event_search" do
    it "includes indexable events when the selected source event allows unrestricted disbursements" do
      user = create(:user)
      source_event = create(:event, plan_type: Event::Plan::HackClubAffiliate)
      create(:organizer_position, user:, event: source_event)

      public_destination = create(:event, is_public: true, is_indexable: true)

      sign_in(user)

      get :event_search, params: { source_event_id: source_event.id }, format: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(public_destination.name)
    end
  end

  describe "#new" do
    it "renders the destination combobox with the selected source event in the async search params" do
      user = create(:user)
      source_event = create(:event)
      destination_event = create(:event)
      create(:organizer_position, user:, event: source_event)
      create(:organizer_position, user:, event: destination_event)

      sign_in(user)

      get :new, params: { source_event_id: source_event.public_id, event_id: destination_event.public_id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("source_event_id=#{source_event.id}")
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
end
