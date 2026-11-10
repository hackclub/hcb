# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /admin/wire_lookup", type: :request do
  let(:auditor) { create(:user, :make_auditor) }

  before do
    auditor_session = create(:user_session, user: auditor, verified: true, expiration_at: 1.hour.from_now)

    allow_any_instance_of(SessionsHelper)
      .to receive(:find_current_session)
      .and_return(auditor_session)
  end

  ["../../bank-accounts?", "../../entities?limit=100&", "a b", "not-a-uetr/../x"].each do |uetr|
    it "rejects #{uetr.inspect} without calling Column" do
      expect(ColumnService).not_to receive(:get)

      get "/admin/wire_lookup", params: { uetr: }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("isn&#39;t a valid UETR or Column transfer ID")
    end
  end

  it "looks up a valid UETR" do
    uetr = "eb6305c9-1f7f-49de-aed0-16487c27b42d"
    expect(ColumnService).to receive(:get)
      .with("/transfers/international-wire/#{uetr}/tracking")
      .and_return({})

    get "/admin/wire_lookup", params: { uetr: }

    expect(response).to have_http_status(:ok)
  end
end
