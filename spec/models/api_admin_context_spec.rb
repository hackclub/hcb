# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiAdminContext do
  def context_for(user, scopes:)
    token = create(:api_token, user:, scopes:)
    described_class.new(user, token)
  end

  let(:admin)      { create(:user, access_level: :admin) }
  let(:superadmin) { create(:user, access_level: :superadmin) }
  let(:auditor)    { create(:user, access_level: :auditor) }
  let(:regular)    { create(:user) }

  describe "#admin?" do
    it "is true only when the user is an admin AND the token carries admin:write" do
      expect(context_for(admin, scopes: "admin:write").admin?).to be(true)
    end

    it "is false when the admin:write scope is missing" do
      expect(context_for(admin, scopes: "admin:read").admin?).to be(false)
      expect(context_for(admin, scopes: "").admin?).to be(false)
    end

    it "is false when the user lacks the admin role even with the scope" do
      expect(context_for(regular, scopes: "admin:write").admin?).to be(false)
      expect(context_for(auditor, scopes: "admin:write").admin?).to be(false)
    end

    it "ignores the user's 'pretend not to be an admin' preference" do
      admin.update!(pretend_is_not_admin: true)
      expect(context_for(admin, scopes: "admin:write").admin?).to be(true)
    end
  end

  describe "#auditor?" do
    it "is true with admin:read for every auditor-level role (auditor, admin, superadmin)" do
      expect(context_for(auditor, scopes: "admin:read").auditor?).to be(true)
      expect(context_for(admin, scopes: "admin:read").auditor?).to be(true)
      expect(context_for(superadmin, scopes: "admin:read").auditor?).to be(true)
    end

    it "is false when the admin:read scope is missing (admin:write does not imply it)" do
      expect(context_for(admin, scopes: "admin:write").auditor?).to be(false)
      expect(context_for(auditor, scopes: "").auditor?).to be(false)
    end

    it "is false for a non-auditor user even with the scope" do
      expect(context_for(regular, scopes: "admin:read").auditor?).to be(false)
    end
  end

  describe "#admin_override_pretend?" do
    it "requires the admin:read scope alongside an auditor-level role" do
      expect(context_for(admin,   scopes: "admin:read").admin_override_pretend?).to be(true)
      expect(context_for(auditor, scopes: "admin:read").admin_override_pretend?).to be(true)
    end

    it "is false without the admin:read scope" do
      expect(context_for(admin, scopes: "admin:write").admin_override_pretend?).to be(false)
      expect(context_for(admin, scopes: "").admin_override_pretend?).to be(false)
    end

    it "is false for a user without an auditor-level role" do
      expect(context_for(regular, scopes: "admin:read").admin_override_pretend?).to be(false)
    end
  end

  describe "a nil token" do
    it "fails closed for every admin predicate" do
      context = described_class.new(admin, nil)

      expect(context.admin?).to be_falsey
      expect(context.auditor?).to be_falsey
      expect(context.admin_override_pretend?).to be_falsey
    end
  end

  describe "transparent delegation" do
    it "delegates non-admin methods and identity to the wrapped user" do
      context = context_for(regular, scopes: "")

      expect(context.email).to eq(regular.email)
      expect(context == regular).to be(true)
      expect(regular == context).to be(true)
      expect(context.is_a?(User)).to be(true)
    end
  end
end
