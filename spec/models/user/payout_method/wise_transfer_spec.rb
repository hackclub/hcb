# frozen_string_literal: true

require "rails_helper"

RSpec.describe User::PayoutMethod::WiseTransfer do
  [User::PayoutMethod::WiseTransfer, LegalEntity::PayoutMethod::WiseTransfer].each do |model|
    describe "#{model} recipient ID validation" do
      it "allows an unset recipient ID or a bare UUID" do
        [nil, "", "3e219880-5f3e-4230-8a5a-9c8c25af26bb"].each do |id|
          instance = model.new(wise_recipient_id: id)
          instance.validate
          expect(instance.errors[:wise_recipient_id]).to be_empty
        end
      end

      it "rejects URLs and malformed IDs" do
        ["https://wise.com/recipients/3e219880-5f3e-4230-8a5a-9c8c25af26bb", "NOPE", "a" * 36, "-" * 36].each do |id|
          instance = model.new(wise_recipient_id: id)
          instance.validate
          expect(instance.errors[:wise_recipient_id]).to eq(["is not a valid Wise recipient ID"])
        end
      end
    end
  end
end
