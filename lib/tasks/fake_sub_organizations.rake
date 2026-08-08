# frozen_string_literal: true

# Development-only seeding for the sub-organizations graph. Builds a
# deliberately awkward hierarchy under an existing organization — deep chains,
# wide fan-outs, lopsided branches, long names, negative balances — so the graph
# layout can be eyeballed against the cases that actually break it.
#
#   bin/rails fake_sub_orgs:seed              # under hack_the_seas
#   bin/rails fake_sub_orgs:seed[some-slug]
#   bin/rails fake_sub_orgs:destroy           # removes everything it created

namespace :fake_sub_orgs do
  SLUG_PREFIX = "fake-suborg"
  MEMO_PREFIX = "🌊 Fake seed for "

  # [name, [children...]] — nil/omitted children means a leaf.
  def fake_tree
    [
      # A wide-but-shallow branch: the common "lots of chapters" shape.
      ["Marine Robotics Division", [
        ["ROV Team Alpha", [
          ["Sensor Pod"],
          ["Navigation Pod"],
          ["Comms Pod"],
          ["Ballast Pod"],
        ]],
        ["ROV Team Bravo", [
          ["Sensor Pod"],
          ["Navigation Pod"],
          ["Comms Pod"],
          ["Ballast Pod"],
        ]],
        ["ROV Team Charlie", [
          ["Sensor Pod"],
          ["Navigation Pod"],
          ["Comms Pod"],
          ["Ballast Pod"],
        ]],
      ]],

      # A deep single-child chain: worst case for vertical growth.
      ["Deep Sea Trench Expedition", [
        ["Layer 1 — Sunlight Zone", [
          ["Layer 2 — Twilight Zone", [
            ["Layer 3 — Midnight Zone", [
              ["Layer 4 — Abyssal Zone", [
                ["Layer 5 — Hadal Zone"],
              ]],
            ]],
          ]],
        ]],
      ]],

      # Enough leaf children to trip the "+N organizations" collapse.
      ["Coastal Chapters Network", (1..25).map { |i| ["Coastal Chapter ##{i}"] }],

      # Lopsided: one heavy child next to a couple of leaves.
      ["Research Vessel Program", [
        ["RV Nautilus", (1..9).map { |i| ["Nautilus Cruise #{i}"] }],
        ["RV Meridian"],
        ["RV Kelpie"],
      ]],

      # Names that stress text measurement and truncation.
      ["The Extraordinarily Long Sub-Organization Name For Testing Label Truncation Behaviour"],
      ["🐙"],
      ["Sea Turtle Conservation Fund (Pacific Chapter, Northern Division)", [
        ["Nesting Beach Survey"],
        ["Hatchery Ops"],
      ]],

      # Mixed depths under one parent: some children are leaves, some aren't.
      ["Education & Outreach", [
        ["Dockside Workshops", [
          ["Knot Tying"],
          ["Chart Reading"],
        ]],
        ["School Visits"],
        ["Summer Camp", [
          ["Week 1"],
          ["Week 2"],
          ["Week 3"],
          ["Week 4"],
          ["Week 5"],
          ["Week 6"],
        ]],
        ["Newsletter"],
      ]],
    ]
  end

  desc "Create a complicated fake sub-organization tree under an org (default: hack_the_seas)"
  task :seed, [:slug] => :environment do |_t, args|
    abort "Refusing to run outside development." unless Rails.env.development?

    root = Event.friendly.find(args[:slug] || "hack_the_seas")
    user = root.point_of_contact || User.first
    abort "No user to use as point of contact." if user.nil?

    puts "Seeding fake sub-organizations under #{root.name} (##{root.id})…"

    created = []
    counter = 0

    build = lambda do |parent, spec|
      spec.each do |(name, children)|
        counter += 1
        slug = "#{SLUG_PREFIX}-#{counter}"
        event = Event.create_with(
          name:,
          parent:,
          point_of_contact: user,
          can_front_balance: true,
          is_public: true,
          created_at: rand(1..300).days.ago
        ).create_or_find_by!(slug:)
        created << event
        build.call(event, children) if children.present?
      end
    end

    build.call(root, fake_tree)

    puts "  #{created.size} organizations."

    give_balances(created, user)
    give_cards(created, user)

    Rails.cache.delete("sub_organizations_graph_#{root.id}")
    puts "Done. Visit /#{root.slug}/sub_organizations"
  end

  desc "Remove everything fake_sub_orgs:seed created"
  task destroy: :environment do
    abort "Refusing to run outside development." unless Rails.env.development?

    events = Event.where("slug LIKE ?", "#{SLUG_PREFIX}-%")
    parent_ids = events.pluck(:parent_id).uniq
    puts "Removing #{events.count} fake sub-organizations…"

    destroy_transactions
    StripeCard.where(event_id: events).delete_all
    Event::Plan.where(event_id: events).delete_all
    Event::Configuration.where(event_id: events).delete_all
    FriendlyId::Slug.where(sluggable_type: "Event", sluggable_id: events).delete_all
    events.delete_all

    parent_ids.each { |id| Rails.cache.delete("sub_organizations_graph_#{id}") }
    puts "Done."
  end

  # Transactions are matched by memo rather than by event, so a re-seed after a
  # destroy can't pick up the previous run's transactions and double a balance.
  def destroy_transactions
    canonical = CanonicalTransaction.where("memo LIKE ?", "#{MEMO_PREFIX}%")
    return if canonical.empty?

    puts "  Removing #{canonical.count} fake transactions…"

    mappings = CanonicalEventMapping.where(canonical_transaction_id: canonical)
    Fee.where(canonical_event_mapping_id: mappings).delete_all
    mappings.delete_all

    hashed_ids = CanonicalHashedMapping.where(canonical_transaction_id: canonical)
                                       .pluck(:hashed_transaction_id)
    CanonicalHashedMapping.where(canonical_transaction_id: canonical).delete_all
    canonical.delete_all

    hashed = HashedTransaction.where(id: hashed_ids)
    raw_ids = hashed.pluck(:raw_csv_transaction_id).compact
    hashed.delete_all
    RawCsvTransaction.where(id: raw_ids).delete_all
  end

  # Balances come from the transaction engine, so each organization gets a real
  # (if nonsensical) settled transaction. A few are negative to exercise the
  # "-$" formatting, and a few are left at zero.
  def give_balances(events, user)
    fundable = events.reject.with_index { |_e, i| (i % 7).zero? }
    puts "  Creating #{fundable.size} transactions…"

    memos = {}
    fundable.each_with_index do |event, i|
      # RawCsvTransaction amounts are in dollars; the engine converts to cents.
      amount = if (i % 9).zero?
                 -rand(5..2_500)
               else
                 rand(10..95_000)
               end
      memo = "#{MEMO_PREFIX}#{event.slug}"
      memos[memo] = event
      ::RawCsvTransactionService::Create.new(
        unique_bank_identifier: "FSMAIN",
        date: rand(1..90).days.ago.iso8601(3),
        memo:,
        amount:
      ).run
    end

    ::TransactionEngine::HashedTransactionService::RawCsvTransaction::Import.new.run
    ::TransactionEngine::CanonicalTransactionService::Import::All.new.run

    CanonicalTransaction.where(memo: memos.keys).find_each do |ct|
      event = memos[ct.memo]
      next if event.nil?

      CanonicalEventMapping.create!(canonical_transaction: ct, event:, user:)
    end
  end

  # The graph shows an active card count per organization; give a subset a few
  # cards so that number isn't uniformly zero.
  def give_cards(events, user)
    cardholder = StripeCardholder.create_with(
      user:,
      stripe_name: user.name.presence || "Fake Seed Cardholder",
      stripe_email: user.email
    ).find_or_create_by!(stripe_id: "ich_fake_seed_cardholder")

    count = 0
    events.each_with_index do |event, i|
      next if (i % 3).zero?

      (1 + (i % 4)).times do |n|
        card = StripeCard.new(
          event:,
          stripe_cardholder: cardholder,
          card_type: :virtual,
          stripe_status: "active",
          stripe_id: "ic_fake_#{event.id}_#{n}",
          last4: format("%04d", rand(10_000)),
          stripe_brand: "Visa",
          stripe_exp_month: 12,
          stripe_exp_year: Date.current.year + 3,
          initially_activated: true
        )
        card.skip_notify_user = true
        card.save!(validate: false)
        count += 1
      end
    end

    puts "  Created #{count} cards."
  end
end
