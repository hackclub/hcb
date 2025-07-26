# frozen_string_literal: true

require "rails_helper"

RSpec.describe FeeRelationship, type: :model do
  let(:fee_relationship) { create(:fee_relationship) }

  it "is valid" do
    expect(fee_relationship).to be_valid
  end

  describe "fee_amount" do
    it "defaults to nil" do
      expect(fee_relationship.fee_amount).to be_nil
    end

    context "when before_validation is called" do
      let(:transaction) { create(:transaction, amount: 100) }
      let(:event) do
        event = create(:event)
        event.plan.update(type: Event::Plan::FivePercent)
        event.reload
      end
      let(:fee_relationship) { create(:fee_relationship, fee_applies:, t_transaction: transaction, event:) }

      context "when fee_applies is true" do
        let(:fee_applies) { true }

        it "calculates fee_amount off the transaction and sponsorship fee" do
          expect(fee_relationship).to receive(:calculate_fee).and_call_original

          fee_relationship.save

          expect(fee_relationship.reload.fee_amount).to eql(5)
        end

        context "when fee amount already exists on the fee relationship" do
          before do
            fee_relationship.update_column(:fee_amount, 200)
          end

          it "uses the fee_amount on the relationship rather than the transaction" do
            expect(fee_relationship.fee_amount).to eq(200)
          end
        end
      end

      context "when fee_applies is false" do
        let(:fee_applies) { false }

        before do
          fee_relationship.update_column(:fee_amount, 200)
        end

        it "does not change fee_amount" do
          expect(fee_relationship).to receive(:calculate_fee).and_call_original

          fee_relationship.save

          expect(fee_relationship.reload.fee_amount).to eq(200)
        end
      end
    end
  end
end
