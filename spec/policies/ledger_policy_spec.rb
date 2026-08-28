# frozen_string_literal: true

require "rails_helper"

RSpec.describe LedgerPolicy, type: :policy do
  describe "#show?" do
    let(:event) { create(:event) }
    let(:ledger) { event.ledger }
    let(:user) { create(:user) }

    subject { described_class.new(user, ledger).show? }

    context "as a signed-in user with no organizer position" do
      it "is denied" do
        is_expected.to eq(false)
      end
    end

    context "as a reader" do
      before { create(:organizer_position, user:, event:, role: :reader) }

      it "is allowed" do
        is_expected.to eq(true)
      end
    end

    context "as an auditor" do
      let(:user) { create(:user, :make_auditor) }

      it "is allowed even without an organizer position" do
        is_expected.to eq(true)
      end
    end

    context "with a card grant's ledger, which has no event of its own" do
      # Stub transfer_money to avoid disbursement side effects (see ledger_spec.rb)
      before { allow_any_instance_of(CardGrant).to receive(:transfer_money) }

      let(:card_grant) { create(:card_grant) }
      let(:ledger) { card_grant.ledger }

      it "is denied for a signed-in user with no organizer position" do
        is_expected.to eq(false)
      end

      it "is allowed for a reader of the card grant's event" do
        create(:organizer_position, user:, event: card_grant.event, role: :reader)

        is_expected.to eq(true)
      end
    end
  end
end
