# frozen_string_literal: true

require "rails_helper"

RSpec.describe GSuiteAccountsController do
  include SessionSupport

  describe "#unmanage" do
    let(:g_suite) { create(:g_suite) }
    let(:g_suite_account) { create(:g_suite_account, g_suite:) }

    def unmanage!(confirm: g_suite_account.address)
      put(:unmanage, params: { g_suite_account_id: g_suite_account.id, confirm: })
    end

    context "as a non-admin manager" do
      it "is not authorized" do
        user = g_suite.event.users.first
        create_session(user, verified: true)

        unmanage!

        expect(flash[:error]).to eq("You are not authorized to perform this action.")
        expect(GSuiteAccount.exists?(g_suite_account.id)).to be true
      end
    end

    context "as an admin without the feature flag" do
      it "is not authorized" do
        create_session(create(:user, :make_admin), verified: true)

        unmanage!

        expect(flash[:error]).to eq("You are not authorized to perform this action.")
        expect(GSuiteAccount.exists?(g_suite_account.id)).to be true
      end
    end

    context "as an admin with the feature flag" do
      before do
        admin = create(:user, :make_admin)
        Flipper.enable(:unmanage_gsuite_account, admin)
        create_session(admin, verified: true)
      end

      it "unmanages the account" do
        unmanage!

        expect(flash[:success]).to include(g_suite_account.address)
        expect(GSuiteAccount.exists?(g_suite_account.id)).to be false
      end

      it "does nothing when the confirmation doesn't match the address" do
        unmanage!(confirm: "wrong@example.com")

        expect(flash[:error]).to include(g_suite_account.address)
        expect(GSuiteAccount.exists?(g_suite_account.id)).to be true
      end
    end
  end

end
