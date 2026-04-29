# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users::FirstController", type: :request do
  let(:valid_form) do
    {
      user: {
        email: "fresh-#{SecureRandom.hex(4)}@example.invalid",
        full_name: "Probe Probe",
        affiliations_attributes: {
          "0" => {
            name: "first",
            league: "FRC",
            team_number: "9999",
            team_name: "Probe Team",
            role: "student_member",
          }
        }
      }
    }
  end

  describe "POST /first" do
    it "responds with a redirect when the supplied email already belongs to an existing user" do
      existing = create(:user, verified: true)

      params = valid_form.deep_dup
      params[:user][:email] = existing.email.upcase

      expect {
        post "/first", params: params
      }.not_to(change { User.count })

      expect(response.status).to be < 500
      expect(response.status).to eq(302)
    end

    it "returns the same response code for taken and fresh emails so registration cannot be enumerated" do
      existing = create(:user, verified: true)

      taken = valid_form.deep_dup
      taken[:user][:email] = existing.email
      post "/first", params: taken
      taken_status = response.status

      fresh = valid_form.deep_dup
      fresh[:user][:email] = "brand-new-#{SecureRandom.hex(4)}@example.invalid"
      post "/first", params: fresh
      fresh_status = response.status

      expect(taken_status).to eq(fresh_status),
                              "Existing-email branch returned #{taken_status} while new-email branch returned #{fresh_status}; " \
                              "this discrepancy lets an attacker enumerate registered emails."
    end

  end

  describe "DELETE /first/sign_out" do
    it "clears the session_token cookie" do
      delete "/first/sign_out"

      set_cookie_header = response.headers["Set-Cookie"].to_s
      expect(set_cookie_header).to match(/session_token=;|session_token=\s*;/i),
                                   "Expected Set-Cookie response to clear session_token, got: #{set_cookie_header.inspect}"
    end
  end
end
