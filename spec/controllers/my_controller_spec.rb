# frozen_string_literal: true

require "rails_helper"

RSpec.describe MyController do
  render_views

  def sign_in_unverified
    user = create(:user, verified: false, full_name: "Unverified Probe")
    user_session = User::Session.create!(
      user:,
      verified: false,
      session_token: SecureRandom.urlsafe_base64,
      expiration_at: 7.days.from_now,
    )
    cookies.encrypted[:session_token] = {
      value: user_session.session_token,
      expires: User::Session::MAX_SESSION_DURATION.from_now,
      httponly: true,
    }
    user_session
  end

  def sign_in_verified(user = create(:user))
    user_session = User::Session.create!(
      user:,
      verified: true,
      session_token: SecureRandom.urlsafe_base64,
      expiration_at: 7.days.from_now,
    )
    cookies.encrypted[:session_token] = {
      value: user_session.session_token,
      expires: User::Session::MAX_SESSION_DURATION.from_now,
      httponly: true,
    }
    user
  end

  describe "GET #cards" do
    it "renders for an unverified user" do
      sign_in_unverified

      get :cards

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET #reimbursements" do
    it "does not render the authenticated reimbursement-report listing UI for an unverified user" do
      sign_in_unverified

      get :reimbursements

      expect(response.status).to eq(200)
      expect(response.body).to include("Verify your email")
      expect(response.body).not_to include("To review")
    end
  end

  describe "GET #inbox" do
    render_views(false)

    it "sets @locking_count from card_locking_overdue_charges" do
      user = sign_in_verified
      Flipper.enable(:card_locking)

      get :inbox

      expect(response).to have_http_status(:ok)
      expect(controller.instance_variable_get(:@locking_count)).to eq(user.card_locking_overdue_charges.count)
    end

    it "sets @locking_next_due_at for the card locking callout's countdown" do
      sign_in_verified
      Flipper.enable(:card_locking)
      deadline = 11.hours.from_now
      allow_any_instance_of(User).to receive(:card_locking_next_due_at).and_return(deadline)

      get :inbox

      expect(controller.instance_variable_get(:@locking_next_due_at)).to eq(deadline)
    end

    # The callout is behind the kill switch, so cardholders who cannot see it
    # should not pay for the query behind it.
    it "does not query the next deadline when card locking is off" do
      sign_in_verified
      Flipper.disable(:card_locking)
      expect_any_instance_of(User).not_to receive(:card_locking_next_due_at)

      get :inbox
    end
  end

  describe "GET #pay" do
    it "renders even when the user has not received any payments" do
      sign_in_verified

      get :pay

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No payments yet.")
    end

    it "preserves the selected legal entity in payout settings links" do
      user = sign_in_verified
      legal_entity = create(:legal_entity, :business, name: "Hack Club HQ")
      create(:legal_entity_user, user:, legal_entity:)

      get :pay, params: { legal_entity_id: legal_entity.id }

      expect(response).to redirect_to(my_pay_path)
      expect(session[:legal_entity_id]).to eq(legal_entity.id.to_s)

      get :pay

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(settings_payouts_path(legal_entity_id: legal_entity.id))
    end
  end
end
