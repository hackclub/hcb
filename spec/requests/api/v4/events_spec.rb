# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Freezing organizations via the v4 API", type: :request do
  let(:event) { create(:event, is_public: false) }
  let(:user) { create(:user, :make_admin) }
  let(:scopes) { "admin:write" }
  let(:token) { create(:api_token, user:, scopes:) }
  let(:headers) { { "Authorization" => "Bearer #{token.token}" } }

  def freeze_organization(id: event.public_id, params: {})
    post "/api/v4/organizations/#{id}/freeze", params:, headers:, as: :json
  end

  it "freezes an organization without requiring membership or admin:read" do
    expect { freeze_organization }.to change { event.reload.financially_frozen? }.from(false).to(true)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include(
      "id"                 => event.public_id,
      "object"             => "organization",
      "financially_frozen" => true,
      "created_at"         => event.created_at.as_json
    )
  end

  it "accepts an organization slug" do
    freeze_organization(id: event.slug)

    expect(response).to have_http_status(:ok)
    expect(event.reload).to be_financially_frozen
  end

  it "succeeds when the organization is already frozen" do
    event.update!(financially_frozen: true)

    freeze_organization
    freeze_organization

    expect(response).to have_http_status(:ok)
    expect(event.reload).to be_financially_frozen
  end

  it "only freezes the requested sub-organization" do
    parent = create(:event)
    event.update!(parent:)
    sibling = create(:event, parent:)
    child = create(:event, parent: event)

    freeze_organization

    expect(response).to have_http_status(:ok)
    expect(event.reload).to be_financially_frozen
    expect([parent, sibling, child].map { |organization| organization.reload.financially_frozen? }).to eq([false, false, false])
  end

  it "records the acting admin in the audit trail", versioning: true do
    freeze_organization

    expect(response).to have_http_status(:ok)
    version = event.versions.last
    expect(version.whodunnit).to eq(user.id.to_s)
    expect(version.changeset["financially_frozen"]).to eq([false, true])
  end

  it "does not allow request parameters to unfreeze or change other organization settings" do
    original_name = event.name

    freeze_organization(params: { financially_frozen: false, event: { financially_frozen: false, name: "Changed name" } })

    expect(response).to have_http_status(:ok)
    expect(event.reload).to be_financially_frozen
    expect(event.name).to eq(original_name)
  end

  it "returns 404 for an unknown organization" do
    freeze_organization(id: "missing-organization")

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body).to include("error" => "resource_not_found")
  end

  context "with a restricted token" do
    let(:scopes) { "restricted admin:write" }

    it "freezes the organization with only the admin:write permission" do
      freeze_organization

      expect(response).to have_http_status(:ok)
      expect(event.reload).to be_financially_frozen
    end
  end

  context "as a superadmin" do
    let(:user) { create(:user, access_level: :superadmin) }

    it "allows freezing" do
      freeze_organization

      expect(response).to have_http_status(:ok)
      expect(event.reload).to be_financially_frozen
    end
  end

  context "when the admin pretends not to be an admin in the UI" do
    let(:user) { create(:user, :make_admin, pretend_is_not_admin: true) }

    it "honors the explicit admin scope" do
      freeze_organization

      expect(response).to have_http_status(:ok)
      expect(event.reload).to be_financially_frozen
    end
  end

  ["", "write", "admin:read", "restricted", "restricted admin:read"].each do |token_scopes|
    context "with scopes #{token_scopes.inspect}" do
      let(:scopes) { token_scopes }

      it "rejects the admin without freezing the organization" do
        expect { freeze_organization }.not_to(change { event.reload.financially_frozen? })

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body).to eq("error" => "not_authorized")
      end
    end
  end

  [:user, :auditor].each do |access_level|
    context "as an organization manager with access level #{access_level}" do
      let(:user) { create(:user, access_level:) }

      before { create(:organizer_position, user:, event:, role: :manager) }

      it "rejects the user even with admin:write" do
        expect { freeze_organization }.not_to(change { event.reload.financially_frozen? })

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body).to eq("error" => "not_authorized")
      end
    end
  end

  context "without a token" do
    let(:headers) { {} }

    it "returns 401 without freezing the organization" do
      expect { freeze_organization }.not_to(change { event.reload.financially_frozen? })

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq("error" => "invalid_auth")
    end
  end

  context "with an invalid token" do
    let(:headers) { { "Authorization" => "Bearer invalid" } }

    it "returns 401 without freezing the organization" do
      expect { freeze_organization }.not_to(change { event.reload.financially_frozen? })

      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "with an expired token" do
    let(:token) { create(:api_token, user:, scopes:, created_at: 10.minutes.ago, expires_in: 5.minutes) }

    it "returns 401 without freezing the organization" do
      expect { freeze_organization }.not_to(change { event.reload.financially_frozen? })

      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "with a revoked token" do
    let(:token) { create(:api_token, user:, scopes:, revoked_at: 1.minute.ago) }

    it "returns 401 without freezing the organization" do
      expect { freeze_organization }.not_to(change { event.reload.financially_frozen? })

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
