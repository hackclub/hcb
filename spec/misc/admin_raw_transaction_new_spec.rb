# frozen_string_literal: true

require "rails_helper"

# Covers the /admin/raw_transaction_new form: it posts a hand-rolled set of
# param names (no model), so a renamed field would silently stop reaching
# RawCsvTransactionService::Create.
RSpec.describe AdminController, type: :controller do
  include SessionSupport

  before { create_session(create(:user, :make_admin), verified: true) }

  def form_params(**overrides)
    {
      unique_bank_identifier: "FSMAIN",
      date: "2021-03-01",
      memo: "ACH CREDIT SOMEBODY",
      amount: "500.00",
    }.merge(overrides)
  end

  it "creates the transaction, reading the amount as dollars" do
    expect { post :raw_transaction_create, params: form_params }
      .to change(RawCsvTransaction, :count).by(1)

    transaction = RawCsvTransaction.order(:created_at).last
    expect(transaction.unique_bank_identifier).to eq("FSMAIN")
    expect(transaction.date_posted).to eq(Date.new(2021, 3, 1))
    expect(transaction.memo).to eq("ACH CREDIT SOMEBODY")
    expect(transaction.amount_cents).to eq(50_000)
    expect(flash[:success]).to eq("Success")
  end

  it "accepts a negative amount for money leaving the account" do
    post :raw_transaction_create, params: form_params(amount: "-42.50")
    expect(RawCsvTransaction.order(:created_at).last.amount_cents).to eq(-4_250)
  end

  context "when rendering the form" do
    render_views

    it "offers the bank identifiers we have transactions for" do
      allow_any_instance_of(described_class)
        .to receive(:known_bank_identifiers).and_return(%w[FSMAIN SVB])

      get :raw_transaction_new

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<option value="FSMAIN">FSMAIN</option>))
      expect(response.body).to include(%(<option value="SVB">SVB</option>))
    end
  end
end
