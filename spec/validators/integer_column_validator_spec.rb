# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegerColumnValidator do
  INT4_MAX = 2_147_483_647
  INT4_MIN = -2_147_483_648

  # Each user-settable int4 column this validator guards.
  GUARDED = {
    Donation::Goal         => :amount_cents,
    Donation::Tier         => :amount_cents,
    Reimbursement::Report  => :maximum_amount_cents,
    Reimbursement::Expense => :amount_cents,
    CheckDeposit           => :amount_cents,
    CardGrant              => :amount_cents
  }.freeze

  # Run validations and return the errors on the guarded column. The record need not be
  # otherwise valid; we only assert on the integer-range errors.
  def range_errors(model, column, value)
    record = model.new(column => value)
    record.valid?(:create)
    record.errors[column]
  end

  describe "behavior (via Donation::Goal#amount_cents)" do
    it "rejects a value too big for the column" do
      expect(range_errors(Donation::Goal, :amount_cents, INT4_MAX + 1)).to include("is too big")
    end

    it "rejects a value too small for the column" do
      expect(range_errors(Donation::Goal, :amount_cents, INT4_MIN - 1)).to include("is too small")
    end

    it "accepts an in-range value" do
      errors = range_errors(Donation::Goal, :amount_cents, 500_00)
      expect(errors).not_to include("is too big")
      expect(errors).not_to include("is too small")
    end

    it "accepts nil" do
      errors = range_errors(Donation::Goal, :amount_cents, nil)
      expect(errors).not_to include("is too big")
      expect(errors).not_to include("is too small")
    end
  end

  describe "is wired onto every user-settable int4 money column" do
    GUARDED.each do |model, column|
      it "guards #{model}##{column}" do
        expect(model.validators_on(column).map(&:class)).to include(IntegerColumnValidator)
      end
    end
  end
end
