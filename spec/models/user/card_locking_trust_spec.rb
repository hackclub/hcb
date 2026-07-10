# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  include_context "card locking charges"

  let(:now) { Time.zone.parse("2026-10-10 12:00:00") }

  before { travel_to(now) }

  def materialize_all
    HcbCode.where(hcb_code: user.stripe_cards.flat_map { |c| c.local_hcb_codes.pluck(:hcb_code) })
           .find_each { |hc| hc.materialize_card_locking!(now:) }
  end

  describe "#receipt_trusted?" do
    it "is false when the user has no charges" do
      expect(user.receipt_trusted?(now:)).to eq(false)
    end

    it "is true after a single on-time receipt upload" do
      create_settled_card_charge(user:, settled_at: 5.days.ago, uploaded_at: 4.days.ago)
      materialize_all

      expect(user.reload.receipt_trusted?(now:)).to eq(true)
    end

    it "is false when the most recent determined charge was late" do
      create_settled_card_charge(user:, settled_at: 30.days.ago, uploaded_at: 29.days.ago)
      create_settled_card_charge(user:, settled_at: 20.days.ago, uploaded_at: 1.day.ago)
      materialize_all

      expect(user.reload.receipt_trusted?(now:)).to eq(false)
    end

    it "counts an overdue unresolved charge against the on-time rate" do
      create_settled_card_charge(user:, settled_at: 20.days.ago)
      materialize_all

      expect(user.reload.receipt_trusted?(now:)).to eq(false)
    end

    it "excludes a not-yet-due unresolved charge from the rate" do
      create_settled_card_charge(user:, settled_at: 5.days.ago, uploaded_at: 4.days.ago)
      create_settled_card_charge(user:, settled_at: 1.day.ago)
      materialize_all

      expect(user.reload.receipt_trusted?(now:)).to eq(true)
    end
  end

  describe "#card_locking_has_overdue_charge?" do
    it "is true when a charge is past its receipt deadline and unresolved" do
      create_settled_card_charge(user:, settled_at: 10.days.ago)
      materialize_all

      expect(user.reload.card_locking_has_overdue_charge?(now:)).to eq(true)
    end

    it "is false when the only charge is not yet due" do
      create_settled_card_charge(user:, settled_at: 1.day.ago)
      materialize_all

      expect(user.reload.card_locking_has_overdue_charge?(now:)).to eq(false)
    end
  end

  describe "#last_settled_charge_at" do
    it "returns the max receipt_settled_at across the cardholder's charges" do
      create_settled_card_charge(user:, settled_at: 20.days.ago, uploaded_at: 19.days.ago)
      create_settled_card_charge(user:, settled_at: 5.days.ago, uploaded_at: 4.days.ago)
      materialize_all

      expect(user.reload.last_settled_charge_at).to eq(5.days.ago)
    end
  end

  describe "query count" do
    def queries_during
      count = 0
      sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name])
      end
      yield
      count
    ensure
      ActiveSupport::Notifications.unsubscribe(sub)
    end

    def add_history(n, offset:, card:)
      n.times { |i| create_settled_card_charge(user:, settled_at: (offset + i).days.ago, uploaded_at: (offset + i - 1).days.ago, stripe_card: card) }
    end

    it "computes trust in a constant number of queries as history grows" do
      card = create(:stripe_card, :with_stripe_id, stripe_cardholder: user.stripe_cardholder || create(:stripe_cardholder, user:), event:)
      add_history(5, offset: 30, card:)
      materialize_all
      small = queries_during { User.find(user.id).receipt_trusted?(now:) }

      add_history(20, offset: 60, card:)
      materialize_all
      large = queries_during { User.find(user.id).receipt_trusted?(now:) }

      expect(large).to eq(small)
    end
  end
end
