# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Legacy event-nested payroll position links" do
  it "redirects the contractor page" do
    get "/my-org/payroll_positions/abc123"

    expect(response).to redirect_to("/payroll_positions/abc123")
  end

  it "redirects member pages" do
    get "/my-org/payroll_positions/abc123/contract"

    expect(response).to redirect_to("/payroll_positions/abc123/contract")
  end

  it "keeps the query string" do
    get "/my-org/payroll_positions/abc123?frame=true"

    expect(response).to redirect_to("/payroll_positions/abc123?frame=true")
  end

  it "can't be used to redirect off-site" do
    get "/my-org/payroll_positions/%2F%2Fevil.example"

    expect(URI(response.location).host).to eq("www.example.com")
  end

  it "doesn't swallow the new contractor page" do
    expect(Rails.application.routes.recognize_path("/my-org/payroll_positions/new")).to include(controller: "payroll/positions", action: "new")
  end
end
