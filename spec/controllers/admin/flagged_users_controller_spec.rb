# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::FlaggedUsersController do
  include SessionSupport
  render_views

  describe "#index" do
    it "renders only flagged users" do
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      flagged_user = create(:user, flagged_at: Time.now, flagged_reason: "Suspicious activity", flagged_by: admin)
      create(:user)

      get(:index)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css("table tbody tr td:first-child").map(&:text)).to eq([flagged_user.email])
    end
  end

  describe "#create" do
    it "flags the user with that email" do
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      user = create(:user, flagged_at: nil)

      post(:create, params: { email: user.email, reason: "Suspicious activity" })

      expect(response).to redirect_to(admin_flagged_users_path)
      expect(flash[:success]).to eq("#{user.email} has been flagged.")

      user.reload
      expect(user).to be_flagged
      expect(user.flagged_reason).to eq("Suspicious activity")
      expect(user.flagged_by).to eq(admin)
    end

    it "reports an error and flags nobody when the email doesn't match a user" do
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      post(:create, params: { email: "nobody@example.com", reason: "Suspicious activity" })

      expect(response).to redirect_to(admin_flagged_users_path)
      expect(flash[:error]).to eq("No user found with that email.")
      expect(User.flagged).to be_empty
    end
  end

  describe "#destroy" do
    it "unflags the user" do
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      user = create(:user, flagged_at: Time.now, flagged_reason: "Suspicious activity", flagged_by: admin)

      delete(:destroy, params: { id: user.id })

      expect(response).to redirect_to(admin_flagged_users_path)
      expect(flash[:success]).to eq("#{user.email} has been unflagged.")
      expect(user.reload).not_to be_flagged
    end
  end

end
