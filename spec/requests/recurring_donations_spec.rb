# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Recurring donations", type: :request do
  let(:recurring_donation) { create(:recurring_donation, :canceled) }

  def sign_in(user)
    user_session = create(:user_session, user:, verified: true, expiration_at: 1.hour.from_now)

    allow_any_instance_of(SessionsHelper)
      .to receive(:find_current_session)
      .and_return(user_session)
  end

  describe "POST restart" do
    let(:restart) { instance_double(RecurringDonationService::Restart) }

    before do
      allow(RecurringDonationService::Restart).to receive(:new).with(recurring_donation).and_return(restart)
    end

    it "takes admins to the restarted donation" do
      sign_in(create(:user, :make_admin))
      restarted = create(:recurring_donation, event: recurring_donation.event)
      allow(restart).to receive(:run).and_return(restarted)

      post restart_recurring_donation_path(recurring_donation.url_hash)

      expect(response).to redirect_to(recurring_donation_path(restarted.url_hash))
      expect(flash[:success]).to eq("This donation has been restarted and the first month has been charged.")
    end

    it "shows admins why a restart failed" do
      sign_in(create(:user, :make_admin))
      allow(restart).to receive(:run).and_raise(Stripe::CardError.new("Your card was declined.", nil))

      post restart_recurring_donation_path(recurring_donation.url_hash)

      expect(response).to redirect_to(recurring_donation_path(recurring_donation.url_hash))
      expect(flash[:error]).to eq("This donation couldn't be restarted: Your card was declined.")
    end

    it "doesn't let donors restart their own donation" do
      post restart_recurring_donation_path(recurring_donation.url_hash)

      expect(RecurringDonationService::Restart).not_to have_received(:new)
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end
  end

  describe "GET show" do
    it "shows admins the restart button on a canceled donation" do
      sign_in(create(:user, :make_admin))

      get recurring_donation_path(recurring_donation.url_hash)

      expect(response.body).to include("Restart donation")
    end

    it "hides the restart button from donors" do
      get recurring_donation_path(recurring_donation.url_hash)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Restart donation")
    end
  end

  describe "GET /admin/recurring_donations" do
    it "offers to restart canceled donations and cancel active ones" do
      sign_in(create(:user, :make_admin))
      active = create(:recurring_donation, event: recurring_donation.event)

      get recurring_donations_admin_index_path

      expect(response.body).to include(restart_recurring_donation_path(recurring_donation.url_hash))
      expect(response.body).to include(cancel_recurring_donation_path(active.url_hash))
      expect(response.body).not_to include(restart_recurring_donation_path(active.url_hash))
    end
  end
end
