# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Event::ApplicationsController#admin_activate", type: :request do
  let(:admin) { create(:user, :make_admin, verified: true) }

  before do
    session = create(:user_session, user: admin, verified: true, expiration_at: 1.hour.from_now)
    allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(session)
  end

  it "doesn't activate an application that hasn't been approved" do
    application = create(:event_application, aasm_state: "under_review")

    expect_any_instance_of(Event::Application).not_to receive(:activate_event!)

    post admin_activate_application_path(application), params: { risk_level: "zero" }

    expect(response).to redirect_to(application_path(application))
    expect(flash[:error]).to eq("Approve this application before activating it.")
    expect(application.reload.event).to be_nil
  end
end
