# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::SubscriptionsController, type: :controller do
  include SessionSupport
  render_views

  let(:event) { create(:event) }
  let(:stripe_card) { create(:stripe_card, :with_stripe_id, event:) }

  before { create_session(create(:user, :make_auditor), verified: true) }

  # A settled charge on the card, as the ledger item whose page lists the
  # subscription.
  def settle_charge(merchant_name, days_ago:)
    date = days_ago.days.ago.to_date
    raw_stripe_transaction = create(:raw_stripe_transaction, stripe_card:, stripe_authorization_id: SecureRandom.hex(8), date_posted: date)
    raw_stripe_transaction.stripe_transaction["merchant_data"]["name"] = merchant_name
    raw_stripe_transaction.save!

    canonical_transaction = create(:canonical_transaction, amount_cents: -15_99, date:, transaction_source: raw_stripe_transaction)
    create(:canonical_event_mapping, canonical_transaction:, event:)

    canonical_transaction.reload.local_hcb_code.ledger_item
  end

  describe "GET #transactions" do
    context "for a charge of a subscription" do
      let!(:earlier_charges) { [91, 61, 31].map { |days_ago| settle_charge("Netflix", days_ago:) } }
      let!(:charge) { settle_charge("Netflix", days_ago: 1) }

      it "lists the other charges at the merchant on the card, without the charge itself" do
        other_merchant = settle_charge("Spotify", days_ago: 2)

        get :transactions, params: { item_id: charge.hashid }

        expect(response).to be_successful
        earlier_charges.each do |earlier_charge|
          expect(response.body).to include(ledger_item_path(earlier_charge))
        end
        expect(response.body).not_to include(ledger_item_path(charge))
        expect(response.body).not_to include(ledger_item_path(other_merchant))
      end

      it "puts receipt buttons on the rows only when asked to" do
        # The buttons also need permission to upload, which an auditor lacks.
        create_session(create(:user, :make_admin), verified: true)

        get :transactions, params: { item_id: charge.hashid }
        expect(response.body).not_to include("Upload receipt")

        get :transactions, params: { item_id: charge.hashid, receipt_upload: true }
        expect(response.body).to include("Upload receipt")
      end
    end

    it "has nothing to list for a merchant charged once" do
      charge = settle_charge("Netflix", days_ago: 1)

      get :transactions, params: { item_id: charge.hashid }

      expect(response).to have_http_status(:no_content)
    end

    it "has nothing to list for a transaction that isn't a card charge" do
      item = create(:ledger_item, :with_primary_ledger)

      get :transactions, params: { item_id: item.hashid }

      expect(response).to have_http_status(:no_content)
    end
  end
end
