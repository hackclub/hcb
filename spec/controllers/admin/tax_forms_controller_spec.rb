# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::TaxFormsController do
  include SessionSupport
  render_views

  it "lists an unclaimed form by its import email and finds it by that email" do
    create(:tax_form, legal_entity: create(:legal_entity, name: "Claimed LLC"))
    Tax::Form.create!(aasm_state: :unclaimed, external_service: :manual, import_email: "orpheus@hackclub.com")
    create_session(create(:user, :make_admin), verified: true)

    get(:index, params: { q: "orpheus@" })

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("orpheus@hackclub.com")
    expect(response.body).not_to include("Claimed LLC")
  end
end
