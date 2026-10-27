# frozen_string_literal: true

require "rails_helper"

RSpec.describe StripeCardPolicy, type: :policy do
  let(:event) { create(:event) }
  let(:user) { create(:user) }
  let(:cardholder_user) { user }
  let(:stripe_card) { create(:stripe_card, :with_stripe_id, event:, stripe_cardholder: create(:stripe_cardholder, user: cardholder_user)) }

  subject(:policy) { described_class.new(user, stripe_card) }

  describe "#freeze?" do
    context "as a reader who is not the cardholder" do
      let(:cardholder_user) { create(:user) }

      before { create(:organizer_position, user:, event:, role: :reader) }

      it "is denied" do
        expect(policy.freeze?).to eq(false)
      end
    end

    context "as a reader who is the cardholder" do
      before { create(:organizer_position, user:, event:, role: :reader) }

      it "is denied" do
        expect(policy.freeze?).to eq(false)
      end
    end

    context "as a member who is the cardholder" do
      before { create(:organizer_position, user:, event:, role: :member) }

      it "is allowed" do
        expect(policy.freeze?).to eq(true)
      end
    end

    context "as a member who is not the cardholder" do
      let(:cardholder_user) { create(:user) }

      before { create(:organizer_position, user:, event:, role: :member) }

      it "is denied" do
        expect(policy.freeze?).to eq(false)
      end
    end

    context "as a manager who is not the cardholder" do
      let(:cardholder_user) { create(:user) }

      before { create(:organizer_position, user:, event:, role: :manager) }

      it "is allowed" do
        expect(policy.freeze?).to eq(true)
      end
    end

    context "as a locked member who is the cardholder" do
      let(:user) { create(:user, locked_at: Time.current) }

      before { create(:organizer_position, user:, event:, role: :member) }

      it "is still allowed, locking only blocks re-enabling the card" do
        expect(policy.freeze?).to eq(true)
      end
    end
  end

  describe "#defrost?" do
    context "as a reader who is not the cardholder" do
      let(:cardholder_user) { create(:user) }

      before { create(:organizer_position, user:, event:, role: :reader) }

      it "is denied" do
        expect(policy.defrost?).to eq(false)
      end
    end

    context "as a reader who is the cardholder" do
      before { create(:organizer_position, user:, event:, role: :reader) }

      it "is denied" do
        expect(policy.defrost?).to eq(false)
      end
    end

    context "as a member who is the cardholder" do
      before { create(:organizer_position, user:, event:, role: :member) }

      it "is allowed" do
        expect(policy.defrost?).to eq(true)
      end
    end

    context "as a manager who is not the cardholder" do
      let(:cardholder_user) { create(:user) }

      before { create(:organizer_position, user:, event:, role: :manager) }

      it "is allowed" do
        expect(policy.defrost?).to eq(true)
      end
    end

    context "as an admin with no organizer position" do
      let(:user) { create(:user, :make_admin) }
      let(:cardholder_user) { create(:user) }

      it "is allowed" do
        expect(policy.defrost?).to eq(true)
      end
    end

    context "as a locked member who is the cardholder" do
      let(:user) { create(:user, locked_at: Time.current) }

      before { create(:organizer_position, user:, event:, role: :member) }

      it "is denied" do
        expect(policy.defrost?).to eq(false)
      end
    end

    context "as a locked manager" do
      let(:user) { create(:user, locked_at: Time.current) }
      let(:cardholder_user) { create(:user) }

      before { create(:organizer_position, user:, event:, role: :manager) }

      it "is denied" do
        expect(policy.defrost?).to eq(false)
      end
    end

    context "as a locked admin" do
      let(:user) { create(:user, :make_admin, locked_at: Time.current) }
      let(:cardholder_user) { create(:user) }

      it "is denied" do
        expect(policy.defrost?).to eq(false)
      end
    end

    context "through the v4 API policy context" do
      # Api::V4::ApplicationController#pundit_user wraps the user in an
      # ApiAdminContext, which delegates `locked?` to the underlying user.
      subject(:policy) { described_class.new(ApiAdminContext.new(user, create(:api_token, user:)), stripe_card) }

      before { create(:organizer_position, user:, event:, role: :manager) }

      context "as an unlocked manager" do
        it "is allowed" do
          expect(policy.defrost?).to eq(true)
        end
      end

      context "as a locked manager" do
        let(:user) { create(:user, locked_at: Time.current) }

        it "is denied" do
          expect(policy.defrost?).to eq(false)
        end
      end
    end
  end
end
