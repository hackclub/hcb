# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event::ApplicationsController, type: :request do
  let(:user) { create(:user, legal_first_name: "Fiona", legal_last_name: "Hackworth", preferred_name: "FiFi Hacks") }
  let(:application) { create(:event_application, user:) }

  def sign_in_as(user)
    allow_any_instance_of(SessionsHelper)
      .to receive(:find_current_session)
      .and_return(create(:user_session, user:))
  end

  describe "GET /applications/:id/personal_info" do
    it "prefills the legal name, not the preferred name" do
      sign_in_as(user)

      get personal_info_application_path(application)

      page = Nokogiri::HTML(response.body)
      expect(page.at_css("input[name='event_application[legal_first_name]']")["value"]).to eq("Fiona")
      expect(page.at_css("input[name='event_application[legal_last_name]']")["value"]).to eq("Hackworth")
      expect(page.at_css("input[name='event_application[full_name]']")).to be_nil
    end
  end

  describe "PATCH /applications/:id" do
    it "saves the applicant's legal name" do
      sign_in_as(user)

      patch application_path(application), params: { event_application: { legal_first_name: "Jane", legal_last_name: "Elder" }, return_to: application_path(application) }

      expect(response).to redirect_to(application_path(application))
      expect(user.reload).to have_attributes(legal_first_name: "Jane", legal_last_name: "Elder", full_name: "Jane Elder")
    end

    it "ignores the legacy full_name parameter" do
      sign_in_as(user)

      patch application_path(application), params: { event_application: { full_name: "Someone Else" }, return_to: application_path(application) }

      expect(user.reload).to have_attributes(legal_first_name: "Fiona", legal_last_name: "Hackworth", full_name: "Fiona Hackworth")
    end

    it "rejects a name with unsupported characters without saving it" do
      sign_in_as(user)

      patch application_path(application), params: { event_application: { legal_first_name: "Fiona <script>", legal_last_name: "Hackworth" } }

      expect(response.body).to include("Legal first name may only contain letters")
      expect(user.reload.full_name).to eq("Fiona Hackworth")
    end

    it "does not let the name be removed" do
      sign_in_as(user)

      patch application_path(application), params: { event_application: { legal_first_name: "", legal_last_name: "" } }

      expect(response.body).to include("Legal first name can&#39;t be blank")
      expect(user.reload.full_name).to eq("Fiona Hackworth")
    end

    it "does not let another user change the applicant's name" do
      sign_in_as(create(:user))

      patch application_path(application), params: { event_application: { legal_first_name: "Mallory", legal_last_name: "Attacker" } }

      expect(user.reload).to have_attributes(legal_first_name: "Fiona", legal_last_name: "Hackworth", full_name: "Fiona Hackworth")
    end
  end
end
