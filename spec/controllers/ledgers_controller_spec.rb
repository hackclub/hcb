# frozen_string_literal: true

require "rails_helper"

RSpec.describe LedgersController, type: :controller do
  include SessionSupport

  let(:admin) { create(:user, :make_admin) }
  let(:event) { create(:event) }
  let(:ledger) { event.ledger }

  before { sign_in admin }

  describe "GET #show" do
    it "returns success" do
      get :show, params: { id: ledger.to_param }
      expect(response).to be_successful
    end

    it "returns success with ledger items" do
      items = create_list(:ledger_item, 3)
      items.each do |item|
        create(:ledger_mapping, ledger:, ledger_item: item, on_primary_ledger: true)
      end

      get :show, params: { id: ledger.to_param }
      expect(response).to be_successful
    end
  end

end
