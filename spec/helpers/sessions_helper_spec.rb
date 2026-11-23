# frozen_string_literal: true

require "rails_helper"

RSpec.describe SessionsHelper, type: :helper do
  describe "#organizer_signed_in?" do
    let(:event) { create(:event) }

    def sign_in_as(user)
      allow(helper).to receive_messages(signed_in?: true, current_user: user)
    end

    it "gives auditors reader access no matter which role was checked first", :aggregate_failures do
      sign_in_as(create(:user, :make_auditor))

      expect(helper.organizer_signed_in?(event, as: :member)).to be(false)
      expect(helper.organizer_signed_in?(event)).to be(true)
    end

    it "gives admins member access no matter which role was checked first", :aggregate_failures do
      sign_in_as(create(:user, :make_admin))

      expect(helper.organizer_signed_in?(event, as: :manager)).to be(false)
      expect(helper.organizer_signed_in?(event, as: :member)).to be(true)
    end

    it "doesn't let a staff check leak access to someone without a role", :aggregate_failures do
      sign_in_as(create(:user))

      expect(helper.organizer_signed_in?(event)).to be(false)
      expect(helper.organizer_signed_in?(event, as: :member)).to be(false)
    end

    context "in a sub-organization" do
      let(:parent) { create(:event) }
      let(:event) { create(:event, parent:) }
      let(:user) { create(:user) }

      before { sign_in_as(user) }

      it "doesn't give a parent organization's members member access", :aggregate_failures do
        create(:organizer_position, event: parent, user:, role: :member)

        expect(helper.organizer_signed_in?(event)).to be(true)
        expect(helper.organizer_signed_in?(event, as: :member)).to be(false)
      end

      it "gives a parent organization's managers member access" do
        create(:organizer_position, event: parent, user:, role: :manager)

        expect(helper.organizer_signed_in?(event, as: :member)).to be(true)
      end
    end
  end
end
