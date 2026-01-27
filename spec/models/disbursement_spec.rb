# frozen_string_literal: true

require "rails_helper"

RSpec.describe Disbursement, type: :model do
  let(:disbursement) { create(:disbursement) }

  it "is valid" do
    expect(disbursement).to be_valid
  end

  describe "state machine" do
    describe "initial state" do
      it "starts in reviewing state" do
        expect(disbursement).to be_reviewing
      end
    end

    describe "#mark_approved" do
      context "from reviewing state" do
        let(:user) { create(:user) }
        let(:disbursement) { create(:disbursement, :with_raw_pending_transactions) }

        it "transitions to pending" do
          disbursement.mark_approved!(user)
          expect(disbursement).to be_pending
        end

        it "sets fulfilled_by" do
          disbursement.mark_approved!(user)
          expect(disbursement.fulfilled_by).to eq(user)
        end

        it "sets CPTs to fronted: true" do
          disbursement.mark_approved!(user)
          disbursement.canonical_pending_transactions.each do |cpt|
            expect(cpt.reload.fronted).to be true
          end
        end
      end

      context "from scheduled state" do
        let(:user) { create(:user) }
        let(:disbursement) { create(:disbursement, :scheduled, :with_raw_pending_transactions) }

        it "transitions to pending" do
          disbursement.mark_approved!(user)
          expect(disbursement).to be_pending
        end

        it "sets fulfilled_by" do
          new_user = create(:user)
          disbursement.mark_approved!(new_user)
          expect(disbursement.fulfilled_by).to eq(new_user)
        end
      end
    end

    describe "#mark_scheduled" do
      let(:user) { create(:user) }

      context "from reviewing state" do
        it "transitions to scheduled" do
          disbursement.mark_scheduled!(user)
          expect(disbursement).to be_scheduled
        end

        it "sets fulfilled_by" do
          disbursement.mark_scheduled!(user)
          expect(disbursement.fulfilled_by).to eq(user)
        end
      end

      context "from pending state" do
        let(:disbursement) { create(:disbursement, :pending) }

        it "transitions to scheduled" do
          disbursement.mark_scheduled!(user)
          expect(disbursement).to be_scheduled
        end
      end
    end

    describe "#mark_in_transit" do
      context "from pending state" do
        let(:disbursement) { create(:disbursement, :pending) }

        it "transitions to in_transit" do
          disbursement.mark_in_transit!
          expect(disbursement).to be_in_transit
        end
      end

      context "from scheduled state" do
        let(:disbursement) { create(:disbursement, :scheduled) }

        it "transitions to in_transit" do
          disbursement.mark_in_transit!
          expect(disbursement).to be_in_transit
        end
      end
    end

    describe "#mark_deposited" do
      context "from in_transit state" do
        let(:disbursement) { create(:disbursement, :in_transit) }

        it "transitions to deposited" do
          disbursement.mark_deposited!
          expect(disbursement).to be_deposited
        end
      end
    end

    describe "#mark_rejected" do
      let(:user) { create(:user) }

      context "from reviewing state" do
        let(:disbursement) { create(:disbursement, :with_raw_pending_transactions) }

        it "transitions to rejected" do
          disbursement.mark_rejected!(user)
          expect(disbursement).to be_rejected
        end

        it "sets fulfilled_by" do
          disbursement.mark_rejected!(user)
          expect(disbursement.fulfilled_by).to eq(user)
        end

        it "declines CPTs" do
          disbursement.mark_rejected!(user)
          disbursement.canonical_pending_transactions.each do |cpt|
            expect(cpt.reload).to be_declined
          end
        end

        it "creates rejection activity" do
          PublicActivity.with_tracking do
            expect {
              disbursement.mark_rejected!(user)
            }.to change { PublicActivity::Activity.where(trackable: disbursement, key: "disbursement.rejected").count }.by(1)
          end
        end
      end

      context "from pending state" do
        let(:disbursement) { create(:disbursement, :pending, :with_raw_pending_transactions) }

        it "transitions to rejected" do
          disbursement.mark_rejected!(user)
          expect(disbursement).to be_rejected
        end
      end

      context "from scheduled state" do
        let(:disbursement) { create(:disbursement, :scheduled, :with_raw_pending_transactions) }

        it "transitions to rejected" do
          disbursement.mark_rejected!(user)
          expect(disbursement).to be_rejected
        end
      end
    end

    describe "#mark_errored" do
      context "from pending state" do
        let(:disbursement) { create(:disbursement, :pending, :with_raw_pending_transactions) }

        it "transitions to errored" do
          disbursement.mark_errored!
          expect(disbursement).to be_errored
        end

        it "declines CPTs" do
          disbursement.mark_errored!
          disbursement.canonical_pending_transactions.each do |cpt|
            expect(cpt.reload).to be_declined
          end
        end
      end

      context "from in_transit state" do
        let(:disbursement) { create(:disbursement, :in_transit, :with_raw_pending_transactions) }

        it "transitions to errored" do
          disbursement.mark_errored!
          expect(disbursement).to be_errored
        end
      end
    end
  end

  describe "validations" do
    # Note: source_event_id and event_id presence validations can't be easily tested
    # because the frozen check callback runs first and raises NoMethodError on nil

    it "requires amount" do
      disbursement = build(:disbursement, amount: nil)
      expect(disbursement).not_to be_valid
      expect(disbursement.errors[:amount]).to include("can't be blank")
    end

    it "requires name" do
      disbursement = build(:disbursement, name: nil)
      expect(disbursement).not_to be_valid
      expect(disbursement.errors[:name]).to include("can't be blank")
    end

    it "requires amount to be greater than 0" do
      disbursement = build(:disbursement, amount: 0)
      expect(disbursement).not_to be_valid
      expect(disbursement.errors[:amount]).to include("must be greater than 0")
    end

    it "does not allow negative amounts" do
      disbursement = build(:disbursement, amount: -100)
      expect(disbursement).not_to be_valid
      expect(disbursement.errors[:amount]).to include("must be greater than 0")
    end

    describe "events_are_different" do
      it "does not allow same source and destination event" do
        event = create(:event)
        disbursement = build(:disbursement, event: event, source_event: event)
        expect(disbursement).not_to be_valid
        expect(disbursement.errors[:event]).to include("must be different than source event")
      end

      it "allows same event with different subledgers" do
        event = create(:event)
        source_subledger = create(:subledger, event: event)
        destination_subledger = create(:subledger, event: event)
        disbursement = build(:disbursement, event: event, source_event: event,
                                            source_subledger: source_subledger,
                                            destination_subledger: destination_subledger)
        expect(disbursement.errors[:event]).to be_empty
      end
    end

    describe "events_are_not_demos" do
      it "does not allow demo destination event on create" do
        demo_event = create(:event, :demo_mode)
        disbursement = build(:disbursement, event: demo_event)
        expect(disbursement).not_to be_valid
        expect(disbursement.errors[:event]).to include("cannot be a demo event")
      end

      it "does not allow demo source event on create" do
        demo_event = create(:event, :demo_mode)
        disbursement = build(:disbursement, source_event: demo_event)
        expect(disbursement).not_to be_valid
        expect(disbursement.errors[:source_event]).to include("cannot be a demo event")
      end
    end

    describe "scheduled_on_must_be_in_the_future" do
      it "does not allow scheduled_on in the past" do
        disbursement = build(:disbursement, scheduled_on: 1.day.ago)
        expect(disbursement).not_to be_valid
        expect(disbursement.errors[:scheduled_on]).to include("must be in the future")
      end

      it "does not allow scheduled_on today" do
        disbursement = build(:disbursement, scheduled_on: Date.today)
        expect(disbursement).not_to be_valid
        expect(disbursement.errors[:scheduled_on]).to include("must be in the future")
      end

      it "allows scheduled_on in the future" do
        disbursement = build(:disbursement, scheduled_on: 1.week.from_now.to_date)
        disbursement.valid?
        expect(disbursement.errors[:scheduled_on]).to be_empty
      end

      it "allows nil scheduled_on" do
        disbursement = build(:disbursement, scheduled_on: nil)
        disbursement.valid?
        expect(disbursement.errors[:scheduled_on]).to be_empty
      end
    end

    describe "frozen source event" do
      it "blocks creation when source event is frozen" do
        frozen_event = create(:event)
        frozen_event.update!(financially_frozen: true)
        disbursement = build(:disbursement, source_event: frozen_event)
        expect(disbursement).not_to be_valid
        expect(disbursement.errors[:base].first).to include("is currently frozen")
      end
    end
  end

  describe "helper methods" do
    describe "#hcb_code" do
      it "returns the correct HCB code format" do
        expect(disbursement.hcb_code).to eq("HCB-500-#{disbursement.id}")
      end
    end

    describe "#canonical_transactions" do
      it "returns CTs with matching hcb_code" do
        ct1 = create(:canonical_transaction)
        ct1.update_column(:hcb_code, disbursement.hcb_code)
        ct2 = create(:canonical_transaction)
        ct2.update_column(:hcb_code, disbursement.hcb_code)
        create(:canonical_transaction) # unrelated CT

        # Clear memoization
        disbursement.instance_variable_set(:@canonical_transactions, nil)
        expect(disbursement.canonical_transactions).to contain_exactly(ct1, ct2)
      end

      it "returns empty when no matching CTs" do
        expect(disbursement.canonical_transactions).to be_empty
      end
    end

    describe "#canonical_pending_transactions" do
      it "returns CPTs with matching hcb_code" do
        # Create CPTs manually and set their hcb_code after creation
        cpt1 = create(:canonical_pending_transaction, amount_cents: -disbursement.amount)
        cpt1.update_column(:hcb_code, disbursement.hcb_code)
        cpt2 = create(:canonical_pending_transaction, amount_cents: disbursement.amount)
        cpt2.update_column(:hcb_code, disbursement.hcb_code)

        # Clear memoization
        disbursement.instance_variable_set(:@canonical_pending_transactions, nil)
        cpts = disbursement.canonical_pending_transactions
        expect(cpts.count).to eq(2)
        cpts.each do |cpt|
          expect(cpt.hcb_code).to eq(disbursement.hcb_code)
        end
      end
    end

    describe "#processed?" do
      it "returns true when in_transit" do
        disbursement = create(:disbursement, :in_transit)
        expect(disbursement.processed?).to be true
      end

      it "returns true when deposited" do
        disbursement = create(:disbursement, :deposited)
        expect(disbursement.processed?).to be true
      end

      it "returns false when reviewing" do
        expect(disbursement.processed?).to be false
      end

      it "returns false when pending" do
        disbursement = create(:disbursement, :pending)
        expect(disbursement.processed?).to be false
      end
    end

    describe "#fulfilled?" do
      it "returns true when deposited" do
        disbursement = create(:disbursement, :deposited)
        expect(disbursement.fulfilled?).to be true
      end

      it "returns false when in_transit" do
        disbursement = create(:disbursement, :in_transit)
        expect(disbursement.fulfilled?).to be false
      end

      it "returns false when pending" do
        disbursement = create(:disbursement, :pending)
        expect(disbursement.fulfilled?).to be false
      end
    end

    describe "#state" do
      it "returns :success when fulfilled" do
        disbursement = create(:disbursement, :deposited)
        expect(disbursement.state).to eq(:success)
      end

      it "returns :error when rejected" do
        disbursement = create(:disbursement, :rejected)
        expect(disbursement.state).to eq(:error)
      end

      it "returns :error when errored" do
        disbursement = create(:disbursement, :errored)
        expect(disbursement.state).to eq(:error)
      end

      it "returns :info when scheduled" do
        disbursement = create(:disbursement, :scheduled)
        expect(disbursement.state).to eq(:info)
      end

      it "returns :muted when reviewing" do
        expect(disbursement.state).to eq(:muted)
      end
    end

    describe "#state_text" do
      it "returns 'fulfilled' when deposited" do
        disbursement = create(:disbursement, :deposited)
        expect(disbursement.state_text).to eq("fulfilled")
      end

      it "returns 'rejected' when rejected without prior approval" do
        disbursement = create(:disbursement, :rejected)
        expect(disbursement.state_text).to eq("rejected")
      end

      it "returns 'canceled' when rejected after approval" do
        disbursement = create(:disbursement, :rejected, pending_at: 1.day.ago)
        expect(disbursement.state_text).to eq("canceled")
      end

      it "returns 'scheduled' when scheduled" do
        disbursement = create(:disbursement, :scheduled)
        expect(disbursement.state_text).to eq("scheduled")
      end

      it "returns 'errored' when errored" do
        disbursement = create(:disbursement, :errored)
        expect(disbursement.state_text).to eq("errored")
      end

      it "returns 'pending' when reviewing" do
        expect(disbursement.state_text).to eq("pending")
      end
    end

    describe "#transferred_at" do
      it "returns approved_at when set" do
        freeze_time do
          disbursement = create(:disbursement, :pending)
          expect(disbursement.transferred_at).to eq(disbursement.approved_at)
        end
      end

      it "falls back to in_transit_at when approved_at is nil" do
        freeze_time do
          disbursement = create(:disbursement, :in_transit, pending_at: nil)
          expect(disbursement.transferred_at).to eq(disbursement.in_transit_at)
        end
      end
    end
  end
end
