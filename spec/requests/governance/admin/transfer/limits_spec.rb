# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /users/:id/update_admin_transfer_limit", type: :request do
  let(:superadmin) { create(:user, access_level: :superadmin) }
  let(:admin) { create(:user, :make_admin) }
  let!(:limit) { create(:governance_admin_transfer_limit, user: admin, amount_cents: 1_000_00) }

  def sign_in_with(session)
    allow_any_instance_of(SessionsHelper)
      .to receive(:find_current_session)
      .and_return(session)
  end

  it "lets a superadmin update a transfer limit" do
    sign_in_with(create(:user_session, user: superadmin, expiration_at: 1.hour.from_now))

    post "/users/#{admin.id}/update_admin_transfer_limit", params: { limit_amount: "5000" }

    expect(limit.reload.amount_cents).to eq(5_000_00)
  end

  it "does not let an admin impersonating a superadmin update a transfer limit" do
    sign_in_with(
      create(
        :user_session,
        user: superadmin,
        impersonated_by: admin,
        expiration_at: 1.hour.from_now,
      )
    )

    post "/users/#{admin.id}/update_admin_transfer_limit", params: { limit_amount: "999999" }

    expect(limit.reload.amount_cents).to eq(1_000_00)
  end
end
