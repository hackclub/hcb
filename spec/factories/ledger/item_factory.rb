# frozen_string_literal: true

FactoryBot.define do
  factory :ledger_item, class: "Ledger::Item" do
    amount_cents { 1000 }
    memo { "Test ledger item" }
    date { Time.current }
    short_code { "J3PDG" }
    marked_no_or_lost_receipt_at { nil }

    # Custom factory strategy to handle primary_ledger validation
    to_create do |instance|
      # Save without validation first
      instance.save(validate: false)

      # Create primary mapping
      primary_ledger = ::Ledger.new(primary: true, event: FactoryBot.create(:event))
      primary_ledger.save(validate: false)

      Ledger::Mapping.create!(
        ledger: primary_ledger,
        ledger_item: instance,
        on_primary_ledger: true
      )

      # Reload to pick up the association
      instance.reload

      # Now validate to ensure everything is correct
      instance.validate!
    end

    trait :without_primary_ledger do
      to_create do |instance|
        # Just save without validation and without creating primary mapping
        instance.save(validate: false)
      end
    end
  end
end
