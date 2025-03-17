# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiptsController do
  context "models including Receiptable" do
    it "are explicitly registered" do
      Rails.application.eager_load!
      ApplicationRecord.descendants
                       .filter { _1.include?(Receiptable) }
                       .each do |klass|
        expect(ReceiptsController::RECEIPTABLE_TYPE_MAP).to have_key(klass.to_s)
      end
    end
  end
end
