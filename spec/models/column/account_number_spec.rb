# frozen_string_literal: true

require "rails_helper"

RSpec.describe Column::AccountNumber, type: :model do
  it "fails validation when event is in playground mode" do
    event = create(:event, :demo_mode)

    expect(event.build_column_account_number).to_not be_valid
  end

  it "creates an account number remotely on Column" do
    event = create(:event)

    expect(ColumnService).to receive(:post).with(/\/account-numbers\Z/, { description: /#{event.id}/, idempotency_key: anything }).and_return({
                                                                                                                                                "id"             => "acno_1234",
                                                                                                                                                "account_number" => "1234",
                                                                                                                                                "routing_number" => "1234",
                                                                                                                                                "bic"            => "1234",
                                                                                                                                              })

    account_number = event.create_column_account_number!

    expect(account_number.account_number).to eq("1234")
    expect(account_number.routing_number).to eq("1234")
    expect(account_number.bic_code).to eq("1234")
    expect(account_number.column_id).to eq("acno_1234")
  end
end
