# frozen_string_literal: true

require "rails_helper"
require "csv"

RSpec.describe CardGrantService::BulkCreate do
  let(:event) { create(:event, :with_positive_balance) }
  let(:sent_by) { create(:user) }

  before do
    create(:organizer_position, :manager, event:, user: sent_by)
    create(:card_grant_setting, event:)
  end

  def csv_file_from_content(content)
    StringIO.new(content)
  end

  describe "#run" do
    context "with valid CSV" do
      it "creates card grants for each row" do
        csv_content = <<~CSV
          email,amount_cents,purpose,one_time_use,invite_message
          alice@example.com,1000,Pizza party,false,Welcome!
          bob@example.com,2000,Supplies,true,Thanks for joining
        CSV

        result = described_class.new(
          event:,
          csv_file: csv_file_from_content(csv_content),
          sent_by:
        ).run

        expect(result.success?).to be true
        expect(result.card_grants.count).to eq(2)
        expect(result.errors).to be_empty

        alice_grant = result.card_grants.find { |g| g.email == "alice@example.com" }
        expect(alice_grant.amount_cents).to eq(1000)
        expect(alice_grant.purpose).to eq("Pizza party")
        expect(alice_grant.one_time_use).to be false

        bob_grant = result.card_grants.find { |g| g.email == "bob@example.com" }
        expect(bob_grant.amount_cents).to eq(2000)
        expect(bob_grant.purpose).to eq("Supplies")
        expect(bob_grant.one_time_use).to be true
      end

      it "creates card grants with lock fields" do
        csv_content = <<~CSV
          email,amount_cents,merchant_lock,category_lock,keyword_lock,banned_merchants,banned_categories
          alice@example.com,1000,"123,456","grocery_stores_supermarkets,fast_food_restaurants","\\AHCB-.*\\z","789","gambling"
          bob@example.com,2000,,,,,
        CSV

        result = described_class.new(
          event:,
          csv_file: csv_file_from_content(csv_content),
          sent_by:
        ).run

        expect(result.success?).to be true
        expect(result.card_grants.count).to eq(2)

        alice_grant = result.card_grants.find { |g| g.email == "alice@example.com" }
        expect(alice_grant.merchant_lock).to eq(["123", "456"])
        expect(alice_grant.category_lock).to eq(["grocery_stores_supermarkets", "fast_food_restaurants"])
        expect(alice_grant.keyword_lock).to eq("\\AHCB-.*\\z")
        expect(alice_grant.banned_merchants).to eq(["789"])
        expect(alice_grant.banned_categories).to eq(["gambling"])

        bob_grant = result.card_grants.find { |g| g.email == "bob@example.com" }
        expect(bob_grant.merchant_lock).to eq([])
        expect(bob_grant.category_lock).to eq([])
        expect(bob_grant.keyword_lock).to be_nil
        expect(bob_grant.banned_merchants).to eq([])
        expect(bob_grant.banned_categories).to eq([])
      end

      it "sends emails after successful creation" do
        csv_content = <<~CSV
          email,amount_cents
          alice@example.com,1000
          bob@example.com,2000
        CSV

        expect {
          described_class.new(
            event:,
            csv_file: csv_file_from_content(csv_content),
            sent_by:
          ).run
        }.to have_enqueued_mail(CardGrantMailer, :card_grant_notification).exactly(2).times
      end
    end

    context "with validation errors" do
      it "returns errors for missing required headers" do
        csv_content = <<~CSV
          email,purpose
          alice@example.com,Pizza
        CSV

        result = described_class.new(
          event:,
          csv_file: csv_file_from_content(csv_content),
          sent_by:
        ).run

        expect(result.success?).to be false
        expect(result.errors).to include("Missing required headers: amount_cents")
      end

      it "returns errors for invalid email" do
        csv_content = <<~CSV
          email,amount_cents
          not-an-email,1000
        CSV

        result = described_class.new(
          event:,
          csv_file: csv_file_from_content(csv_content),
          sent_by:
        ).run

        expect(result.success?).to be false
        expect(result.errors.first).to include("not a valid email")
      end

      it "returns errors for zero amount" do
        csv_content = <<~CSV
          email,amount_cents
          alice@example.com,0
        CSV

        result = described_class.new(
          event:,
          csv_file: csv_file_from_content(csv_content),
          sent_by:
        ).run

        expect(result.success?).to be false
        expect(result.errors.first).to include("must be an integer greater than 0")
      end

      it "returns errors for non-integer amount" do
        csv_content = <<~CSV
          email,amount_cents
          alice@example.com,10.50
        CSV

        result = described_class.new(
          event:,
          csv_file: csv_file_from_content(csv_content),
          sent_by:
        ).run

        expect(result.success?).to be false
        expect(result.errors.first).to include("must be an integer greater than 0")
      end

      it "returns errors for non-numeric amount" do
        csv_content = <<~CSV
          email,amount_cents
          alice@example.com,abc
        CSV

        result = described_class.new(
          event:,
          csv_file: csv_file_from_content(csv_content),
          sent_by:
        ).run

        expect(result.success?).to be false
        expect(result.errors.first).to include("must be an integer greater than 0")
      end

      it "returns errors for negative amount" do
        csv_content = <<~CSV
          email,amount_cents
          alice@example.com,-1000
        CSV

        result = described_class.new(
          event:,
          csv_file: csv_file_from_content(csv_content),
          sent_by:
        ).run

        expect(result.success?).to be false
        expect(result.errors.first).to include("cannot be negative")
      end

      it "returns errors for purpose exceeding max length" do
        csv_content = <<~CSV
          email,amount_cents,purpose
          alice@example.com,1000,#{"a" * (CardGrant::MAXIMUM_PURPOSE_LENGTH + 1)}
        CSV

        result = described_class.new(
          event:,
          csv_file: csv_file_from_content(csv_content),
          sent_by:
        ).run

        expect(result.success?).to be false
        expect(result.errors.first).to include("exceeds maximum length")
      end

      it "does not create any grants when validation fails" do
        csv_content = <<~CSV
          email,amount_cents
          alice@example.com,1000
          invalid-email,2000
        CSV

        expect {
          described_class.new(
            event:,
            csv_file: csv_file_from_content(csv_content),
            sent_by:
          ).run
        }.not_to change(CardGrant, :count)
      end

      it "does not send emails when validation fails" do
        csv_content = <<~CSV
          email,amount_cents
          alice@example.com,1000
          invalid-email,2000
        CSV

        expect {
          described_class.new(
            event:,
            csv_file: csv_file_from_content(csv_content),
            sent_by:
          ).run
        }.not_to have_enqueued_mail(CardGrantMailer, :card_grant_notification)
      end
    end

    context "with atomic transaction behavior" do
      it "rolls back all grants if one fails during creation" do
        csv_content = <<~CSV
          email,amount_cents
          alice@example.com,1000
          bob@example.com,999999999999
        CSV

        initial_count = CardGrant.count

        expect {
          described_class.new(
            event:,
            csv_file: csv_file_from_content(csv_content),
            sent_by:
          ).run
        }.to raise_error(ActiveModel::RangeError)

        expect(CardGrant.count).to eq(initial_count)
      end
    end

    context "with empty CSV" do
      it "returns error for empty data" do
        csv_content = <<~CSV
          email,amount_cents
        CSV

        result = described_class.new(
          event:,
          csv_file: csv_file_from_content(csv_content),
          sent_by:
        ).run

        expect(result.success?).to be false
        expect(result.errors).to include("CSV file has no data rows")
      end
    end

    context "with case-insensitive headers" do
      it "accepts headers with different casing" do
        csv_content = <<~CSV
          Email,Amount_Cents,Purpose
          alice@example.com,1000,Test purpose
        CSV

        result = described_class.new(
          event:,
          csv_file: csv_file_from_content(csv_content),
          sent_by:
        ).run

        expect(result.success?).to be true
        expect(result.card_grants.count).to eq(1)
        expect(result.card_grants.first.email).to eq("alice@example.com")
      end
    end

    context "with BOM in CSV" do
      it "handles UTF-8 BOM correctly" do
        csv_content = "\xEF\xBB\xBFemail,amount_cents\nalice@example.com,1000\n"

        result = described_class.new(
          event:,
          csv_file: csv_file_from_content(csv_content),
          sent_by:
        ).run

        expect(result.success?).to be true
        expect(result.card_grants.count).to eq(1)
      end
    end

    context "with encoding errors" do
      it "returns friendly error for invalid encoding" do
        csv_content = "email,amount_cents\n\xFF\xFE invalid\n"

        result = described_class.new(
          event:,
          csv_file: csv_file_from_content(csv_content),
          sent_by:
        ).run

        expect(result.success?).to be false
        expect(result.errors.first).to include("UTF-8")
      end
    end

    context "with malformed CSV" do
      it "returns error for unclosed quotes" do
        csv_content = "email,amount_cents\n\"alice@example.com,1000\n"

        result = described_class.new(
          event:,
          csv_file: csv_file_from_content(csv_content),
          sent_by:
        ).run

        expect(result.success?).to be false
        expect(result.errors.first).to include("Invalid CSV format")
      end
    end

    context "with file size limit" do
      it "returns error for files exceeding size limit" do
        large_content = "email,amount_cents\n#{"alice@example.com,1000\n" * 50_000}"
        file = csv_file_from_content(large_content)
        allow(file).to receive(:size).and_return(2.megabytes)

        result = described_class.new(
          event:,
          csv_file: file,
          sent_by:
        ).run

        expect(result.success?).to be false
        expect(result.errors.first).to include("too large")
      end
    end
  end
end
