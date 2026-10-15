# frozen_string_literal: true

require "rails_helper"

RSpec.describe Governance::Admin::Transfer::LimitPolicy, type: :policy do
  describe "#update?" do
    let(:limit) { create(:governance_admin_transfer_limit) }

    subject { described_class.new(user, limit).update? }

    after { Current.reset }

    context "as a superadmin" do
      let(:user) { create(:user, access_level: :superadmin) }

      before { Current.session = create(:user_session, user:) }

      it "is allowed" do
        is_expected.to eq(true)
      end
    end

    context "as an admin impersonating a superadmin" do
      let(:user) { create(:user, access_level: :superadmin) }

      before do
        Current.session = create(:user_session, user:, impersonated_by: create(:user, :make_admin))
      end

      it "is denied" do
        is_expected.to eq(false)
      end
    end

    context "as an admin" do
      let(:user) { create(:user, :make_admin) }

      before { Current.session = create(:user_session, user:) }

      it "is denied" do
        is_expected.to eq(false)
      end
    end
  end
end
