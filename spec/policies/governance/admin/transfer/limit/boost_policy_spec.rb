# frozen_string_literal: true

require "rails_helper"

RSpec.describe Governance::Admin::Transfer::Limit::BoostPolicy, type: :policy do
  let(:boost) { build(:governance_admin_transfer_limit_boost) }

  after { Current.reset }

  %i[create? revoke?].each do |action|
    describe "##{action}" do
      subject { described_class.new(user, boost).public_send(action) }

      context "as a superadmin" do
        let(:user) { create(:user, access_level: :superadmin) }

        before { Current.session = create(:user_session, user:) }

        it { is_expected.to eq(true) }
      end

      context "as an admin impersonating a superadmin" do
        let(:user) { create(:user, access_level: :superadmin) }

        before do
          Current.session = create(:user_session, user:, impersonated_by: create(:user, :make_admin))
        end

        it { is_expected.to eq(false) }
      end

      context "as an admin" do
        let(:user) { create(:user, :make_admin) }

        before { Current.session = create(:user_session, user:) }

        it { is_expected.to eq(false) }
      end
    end
  end
end
