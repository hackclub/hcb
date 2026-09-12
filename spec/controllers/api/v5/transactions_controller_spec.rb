# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V5::TransactionsController do
  include DonationSupport

  render_views

  before do
    allow_any_instance_of(UsersHelper).to receive(:profile_picture_for).and_return("https://gravatar.com/avatar/stubbed")
  end

  let(:transparent) { create(:event, :with_positive_balance, is_public: true) }
  let(:private_org) { create(:event, :with_positive_balance, is_public: false) }

  def authenticate_as(user)
    request.headers["Authorization"] = "Bearer #{create(:api_token, user:).token}"
  end

  # A ledger item mapped to an organization's primary ledger.
  #
  # `Ledger::Item#refresh!` derives amount, status and memo from the canonical
  # transactions behind an item, and a fixture has none — so those are written
  # directly afterwards. This spec is about who may see an item and which of
  # its fields, not about how the engine computes them.
  def ledger_item_for(event, amount_cents: -1000, memo: "Test item")
    item = create(:ledger_item)
    ::Ledger::Mapping.create!(ledger: event.ledger, ledger_item: item, on_primary_ledger: true)
    item.update_columns(amount_cents:, memo:, status: "settled")
    item.reload
  end

  describe "#index" do
    it "lists a transparent organization's transactions without a token" do
      item = ledger_item_for(transparent)

      get :index, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].map { |t| t["id"] }).to include(item.public_id)
    end

    it "does not list a private organization's transactions anonymously" do
      hidden = ledger_item_for(private_org)

      get :index, params: {}, as: :json

      expect(response.parsed_body["data"].map { |t| t["id"] }).not_to include(hidden.public_id)
    end

    it "includes the reader's own organization" do
      hidden = ledger_item_for(private_org)
      user = create(:user)
      create(:organizer_position, user:, event: private_org, role: :reader)
      authenticate_as(user)

      get :index, params: {}, as: :json

      expect(response.parsed_body["data"].map { |t| t["id"] }).to include(hidden.public_id)
    end

    it "filters to one organization" do
      item = ledger_item_for(transparent)
      ledger_item_for(create(:event, :with_positive_balance, is_public: true))

      get :index, params: { organization_id: transparent.public_id }, as: :json

      expect(response.parsed_body["data"].map { |t| t["id"] }).to contain_exactly(item.public_id)
    end
  end

  describe "#show" do
    it "serves a transparent organization's transaction anonymously" do
      item = ledger_item_for(transparent)

      get :show, params: { id: item.public_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("object" => "transaction", "amount_cents" => -1000)
    end

    it "refuses a private organization's transaction anonymously" do
      item = ledger_item_for(private_org)

      get :show, params: { id: item.public_id }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    # Account-verification micro-deposits prove ownership of an external
    # account. The ledger page redacts them from non-organizers; so must this.
    it "redacts account-verification memos from transparency viewers" do
      item = ledger_item_for(transparent, amount_cents: 12, memo: "ACCTVERIFY deposit")

      get :show, params: { id: item.public_id }, as: :json

      expect(response.parsed_body["memo"]).to eq("Account verification")
    end

    # v3 zeroes the amount of an account-verification deposit as well as hiding
    # the memo. Either half alone identifies the deposit, so both are redacted.
    it "zeroes the amount of an account-verification deposit for transparency viewers" do
      item = ledger_item_for(transparent, amount_cents: 12, memo: "ACCTVERIFY deposit")

      get :show, params: { id: item.public_id }, as: :json

      expect(response.parsed_body["amount_cents"]).to eq(0)
    end

    it "uses the lit_ prefix for transaction ids" do
      item = ledger_item_for(transparent)

      get :show, params: { id: item.public_id }, as: :json

      expect(response.parsed_body["id"]).to start_with("lit_")
    end

    it "shows the real memo to an organizer" do
      item = ledger_item_for(private_org, amount_cents: 12, memo: "ACCTVERIFY deposit")
      user = create(:user)
      create(:organizer_position, user:, event: private_org, role: :reader)
      authenticate_as(user)

      get :show, params: { id: item.public_id }, as: :json

      expect(response.parsed_body["memo"]).to eq("ACCTVERIFY deposit")
      expect(response.parsed_body["amount_cents"]).to eq(12)
    end
  end

end
