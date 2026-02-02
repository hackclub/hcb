# frozen_string_literal: true

FactoryBot.define do
  factory :ledger_item, class: "Ledger::Item" do
    amount_cents { 1000 }
    memo { "Test ledger item" }
    date { Time.current }
    short_code { ::HcbCodeService::Generate::ShortCode.new.run }
    marked_no_or_lost_receipt_at { nil }

    trait :with_primary_ledger do
      after(:create) do |item|
        primary_ledger = ::Ledger.new(primary: true, event: FactoryBot.create(:event))
        primary_ledger.save(validate: false)

        Ledger::Mapping.create!(
          ledger: primary_ledger,
          ledger_item: item,
          on_primary_ledger: true
        )
      end
    end
  end
end
