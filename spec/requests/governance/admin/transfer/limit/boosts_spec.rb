# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin transfer limit boosts", type: :request do
  let(:superadmin) { create(:user, access_level: :superadmin) }
  let(:admin) { create(:user, :make_admin) }
  let!(:limit) { create(:governance_admin_transfer_limit, user: admin, amount_cents: 200_000_00) }

  def sign_in_with(session)
    allow_any_instance_of(SessionsHelper)
      .to receive(:find_current_session)
      .and_return(session)
  end

  describe "POST /users/:id/admin_transfer_limit_boosts" do
    let(:params) { { amount: "1000000", duration_in_hours: "36", reason: "One-off grant" } }

    it "lets a superadmin boost a transfer limit" do
      sign_in_with(create(:user_session, user: superadmin, expiration_at: 1.hour.from_now))

      freeze_time do
        post "/users/#{admin.id}/admin_transfer_limit_boosts", params: params

        boost = limit.boosts.sole
        expect(boost.amount_cents).to eq(1_000_000_00)
        expect(boost.expires_at).to eq(36.hours.from_now)
        expect(boost.reason).to eq("One-off grant")
        expect(boost.granted_by).to eq(superadmin)
      end
      expect(limit.reload.effective_amount_cents).to eq(1_200_000_00)
    end

    it "does not create an invalid boost" do
      sign_in_with(create(:user_session, user: superadmin, expiration_at: 1.hour.from_now))

      post "/users/#{admin.id}/admin_transfer_limit_boosts", params: params.merge(duration_in_hours: "2")

      expect(limit.boosts).to be_empty
      expect(flash[:error]).to be_present
    end

    it "does not boost a user without a transfer limit" do
      sign_in_with(create(:user_session, user: superadmin, expiration_at: 1.hour.from_now))
      other_admin = create(:user, :make_admin)

      expect {
        post "/users/#{other_admin.id}/admin_transfer_limit_boosts", params: params
      }.not_to change(Governance::Admin::Transfer::Limit::Boost, :count)
      expect(flash[:error]).to be_present
    end

    it "does not let an admin impersonating a superadmin boost a transfer limit" do
      sign_in_with(
        create(
          :user_session,
          user: superadmin,
          impersonated_by: admin,
          expiration_at: 1.hour.from_now,
        )
      )

      post "/users/#{admin.id}/admin_transfer_limit_boosts", params: params

      expect(limit.boosts).to be_empty
    end
  end

  describe "POST /users/:id/admin_transfer_limit_boosts/:boost_id/revoke" do
    let!(:boost) { create(:governance_admin_transfer_limit_boost, limit:) }

    it "lets a superadmin revoke a boost" do
      sign_in_with(create(:user_session, user: superadmin, expiration_at: 1.hour.from_now))

      post "/users/#{admin.id}/admin_transfer_limit_boosts/#{boost.id}/revoke"

      expect(boost.reload).not_to be_active
      expect(limit.reload.effective_amount_cents).to eq(200_000_00)
    end

    it "does not let an admin revoke a boost" do
      sign_in_with(create(:user_session, user: create(:user, :make_admin), expiration_at: 1.hour.from_now))

      post "/users/#{admin.id}/admin_transfer_limit_boosts/#{boost.id}/revoke"

      expect(boost.reload).to be_active
    end

    it "does not revoke another user's boost" do
      sign_in_with(create(:user_session, user: superadmin, expiration_at: 1.hour.from_now))
      other_boost = create(:governance_admin_transfer_limit_boost)

      post "/users/#{admin.id}/admin_transfer_limit_boosts/#{other_boost.id}/revoke"

      expect(response).to have_http_status(:not_found)
      expect(other_boost.reload).to be_active
    end
  end
end
