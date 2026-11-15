# frozen_string_literal: true

require "rails_helper"

RSpec.describe ColumnService do
  describe ".get / .post path validation" do
    [
      "/institutions/../../entities/ABCDDE11",
      "/transfers/international-wire/../../bank-accounts?/tracking",
      "/transfers/checks/..%2F..%2Fbank-accounts",
      "/transfers/checks/a b",
      "/transfers/checks/x#frag",
      "//evil.example.com/x",
      "/institutions/",
      "institutions/DEUTDEDB",
      "",
    ].each do |path|
      it "rejects #{path.inspect} without sending a request" do
        expect(described_class).not_to receive(:conn)

        expect { described_class.get(path) }.to raise_error(ArgumentError, /invalid Column path/)
        expect { described_class.post(path, idempotency_key: "key") }.to raise_error(ArgumentError, /invalid Column path/)
      end
    end

    it "allows plain id segments" do
      response = double(body: { "ok" => true })
      conn = double
      allow(described_class).to receive(:conn).and_return(conn)

      expect(conn).to receive(:get).with("/transfers/checks/chkt_2abcDEF123", {}).and_return(response)
      expect(described_class.get("/transfers/checks/chkt_2abcDEF123")).to eq("ok" => true)

      expect(conn).to receive(:get).with("/bank-accounts/bacc_123/account-numbers", { limit: 1 }).and_return(response)
      described_class.get("/bank-accounts/bacc_123/account-numbers", limit: 1)
    end
  end
end
