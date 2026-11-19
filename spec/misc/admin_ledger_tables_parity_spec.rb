# frozen_string_literal: true

require "rails_helper"

# See spec/support/admin_ui_parity_helpers.rb.
RSpec.describe AdminController, type: :controller do
  include SessionSupport
  include AdminUiParityHelpers
  render_views

  before { create_session(create(:user, :make_admin), verified: true) }

  describe "index filter forms submit the same params as before" do
    {
      ledger: %w[amount event_id exclude_spending exclude_top_ups mapped_by_human q unmapped user_id],
      ledger_items: %w[amount nonzero q unmapped],
      pending_ledger: %w[event_id q unsettled],
      raw_transactions: %w[unique_bank_identifier],
    }.each do |action, expected|
      it "##{action}" do
        get action

        expect(response).to have_http_status(:ok)
        path = "/admin/#{action}"
        expect(form_fields("get", path)).to eq(expected.sort)
      end
    end
  end

  describe "creation forms submit the same params as before" do
    it "manual raw transaction posts the same four params" do
      get :raw_transaction_new

      expect(form_fields("post", raw_transaction_create_admin_index_path))
        .to eq(%w[amount date memo unique_bank_identifier])
      # Was a free-text field with a YYYY-MM-DD placeholder; a date input
      # submits the same format, which the service already parses.
      expect(page.at_css("input[name=date]")["type"]).to eq("date")
    end
  end
end

RSpec.describe BankAccount do
  it "keeps the same three sync states, with the new shade classes" do
    account = described_class.new

    allow(account).to receive(:should_sync_v2?).and_return(false)
    expect(account.admin_status_color).to be_nil

    allow(account).to receive_messages(should_sync_v2?: true, failing?: true)
    expect(account.admin_status_color).to eq("shade-red")

    allow(account).to receive(:failing?).and_return(false)
    expect(account.admin_status_color).to eq("shade-cyan")
  end
end
