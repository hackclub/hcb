# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrantPolicy, type: :policy do
  subject(:policy) { described_class.new(user, card_grant) }

  let(:event) { create(:event) }
  let(:grantee) { create(:user) }
  let(:organizer) { create(:user) }
  let(:admin) { create(:user, admin: true) }
  let(:card_grant_setting) { create(:card_grant_setting, event:) }

  before do
    allow_any_instance_of(CardGrant).to receive(:transfer_money)
    allow_any_instance_of(CardGrant).to receive(:send_email)
    create(:organizer_position, user: organizer, event:)
    card_grant_setting
  end

  describe "#activate?" do
    context "when allow_stripe_card is true" do
      let(:card_grant) { create(:card_grant, event:, user: grantee, sent_by: organizer, stripe_card: nil, allow_stripe_card: true) }

      context "when user is the cardholder" do
        let(:user) { grantee }

        it "is permitted" do
          expect(policy).to permit_action(:activate)
        end
      end

      context "when user is an admin" do
        let(:user) { admin }

        it "is permitted" do
          expect(policy).to permit_action(:activate)
        end
      end
    end

    context "when allow_stripe_card is false" do
      let(:card_grant) do
        create(:card_grant, event:, user: grantee, sent_by: organizer, stripe_card: nil,
               allow_stripe_card: false, allow_reimbursement_report: true)
      end

      context "when user is the cardholder" do
        let(:user) { grantee }

        it "is not permitted" do
          expect(policy).not_to permit_action(:activate)
        end
      end

      context "when user is an admin" do
        let(:user) { admin }

        it "is not permitted (admin cannot bypass allow_stripe_card: false)" do
          expect(policy).not_to permit_action(:activate)
        end
      end
    end
  end

  describe "#accept_as_reimbursement?" do
    context "when allow_reimbursement_report is true and invite is pending" do
      let(:card_grant) do
        create(:card_grant, event:, user: grantee, sent_by: organizer, stripe_card: nil,
               allow_reimbursement_report: true)
      end
      before { allow(card_grant).to receive(:reimbursement_report).and_return(nil) }

      context "when user is the cardholder" do
        let(:user) { grantee }

        it "is permitted" do
          expect(policy).to permit_action(:accept_as_reimbursement)
        end
      end

      context "when user is an organizer/manager" do
        let(:user) { organizer }

        it "is permitted" do
          expect(policy).to permit_action(:accept_as_reimbursement)
        end
      end
    end

    context "when allow_reimbursement_report is false" do
      let(:card_grant) do
        create(:card_grant, event:, user: grantee, sent_by: organizer, stripe_card: nil,
               allow_stripe_card: true, allow_reimbursement_report: false)
      end
      before { allow(card_grant).to receive(:reimbursement_report).and_return(nil) }

      context "when user is the cardholder" do
        let(:user) { grantee }

        it "is not permitted" do
          expect(policy).not_to permit_action(:accept_as_reimbursement)
        end
      end
    end

    context "when grant already has a stripe card (invite not pending)" do
      let(:stripe_card) { create(:stripe_card, :with_stripe_id) }
      let(:card_grant) do
        create(:card_grant, event:, user: grantee, sent_by: organizer, stripe_card:,
               allow_reimbursement_report: true)
      end
      before { allow(card_grant).to receive(:reimbursement_report).and_return(nil) }

      context "when user is the cardholder" do
        let(:user) { grantee }

        it "is not permitted because pending_invite? is false" do
          expect(card_grant.pending_invite?).to be false
          expect(policy).not_to permit_action(:accept_as_reimbursement)
        end
      end

      context "when user is an admin" do
        let(:user) { admin }

        it "is not permitted because pending_invite? is false" do
          expect(policy).not_to permit_action(:accept_as_reimbursement)
        end
      end
    end

    context "when grant already has a reimbursement report (invite not pending)" do
      let(:card_grant) do
        create(:card_grant, event:, user: grantee, sent_by: organizer, stripe_card: nil,
               allow_reimbursement_report: true)
      end
      before do
        report = instance_double(Reimbursement::Report)
        allow(card_grant).to receive(:reimbursement_report).and_return(report)
      end

      context "when user is the cardholder" do
        let(:user) { grantee }

        it "is not permitted because pending_invite? is false" do
          expect(card_grant.pending_invite?).to be false
          expect(policy).not_to permit_action(:accept_as_reimbursement)
        end
      end
    end

    context "when grant is canceled" do
      let(:card_grant) do
        grant = create(:card_grant, event:, user: grantee, sent_by: organizer, stripe_card: nil,
                       allow_reimbursement_report: true)
        grant.update_columns(status: CardGrant.statuses[:canceled])
        grant
      end
      before { allow(card_grant).to receive(:reimbursement_report).and_return(nil) }

      context "when user is the cardholder" do
        let(:user) { grantee }

        it "is not permitted because grant is not active" do
          expect(card_grant.active?).to be false
          expect(policy).not_to permit_action(:accept_as_reimbursement)
        end
      end
    end
  end
end
