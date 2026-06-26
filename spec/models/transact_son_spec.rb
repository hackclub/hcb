# frozen_string_literal: true

require "rails_helper"

RSpec.describe TransactSON, type: :model do
  let(:transact_son) { create(:transact_son) }

  it "is valid" do
    expect(transact_son).to be_valid
  end
end
