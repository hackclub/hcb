# frozen_string_literal: true

user = User.first

email = Rails.env.staging? ? "staging@bank.engineering" : "admin@bank.engineering"

if user.nil?
  puts "Woah there, there aren't any users! Creating an user (#{email})."
  user = User.create!(email:, full_name: "Stagey McStageface", phone_number: "+19064225632")
end

puts "Continuing with #{user.email}..."

user.make_admin! unless user.admin?

if User.find_by(email: "bank@hackclub.com").nil?
  admin = User.create!(email: "bank@hackclub.com")
  admin.make_admin!
end

demo_event = Event.create_with(
  name: "DevHacks (Demo Event)",
  slug: "devhacks",
  can_front_balance: true,
  point_of_contact: user,
  demo_mode: true,
  created_at: 7.days.ago
).find_or_create_by!(slug: "devhacks")

OrganizerPositionInvite.create!(
  event: demo_event,
  user:,
  sender: user,
)

non_transparent_event = Event.create_with(
  name: "ExpensiCon 2023 (Non-Transparent Event)",
  slug: "expensicon23",
  can_front_balance: true,
  point_of_contact: user,
  created_at: 10.days.ago,
  is_public: false
).find_or_create_by!(slug: "expensicon23")

OrganizerPositionInvite.create!(
  event: non_transparent_event,
  user:,
  sender: user,
)

transparent_event = Event.create_with(
  name: "Hack The Seas (Transparent Event)",
  slug: "hack_the_seas",
  can_front_balance: true,
  point_of_contact: user,
  created_at: 14.days.ago,
  is_public: true
).find_or_create_by!(slug: "hack_the_seas")

OrganizerPositionInvite.create!(
  event: transparent_event,
  user:,
  sender: user,
)

# create incoming transactions for each org

nte_non_pending_transaction = ::RawCsvTransactionService::Create.new(
  unique_bank_identifier: "FSMAIN",
  date: 3.days.ago.iso8601(3),
  memo: "🏦 Donation from David Barrett",
  amount: 8992898
).run

::TransactionEngine::HashedTransactionService::RawCsvTransaction::Import.new.run
::TransactionEngine::CanonicalTransactionService::Import::All.new.run

CanonicalEventMapping.create!({
                                canonical_transaction_id: CanonicalTransaction.last.id,
                                event_id: non_transparent_event.id,
                                user_id: user.id
                              })

te_non_pending_transaction = ::RawCsvTransactionService::Create.new(
  unique_bank_identifier: "FSMAIN",
  date: 9.days.ago.iso8601(3),
  memo: "🏦 Funding From HQ",
  amount: 8100381
).run

::TransactionEngine::HashedTransactionService::RawCsvTransaction::Import.new.run
::TransactionEngine::CanonicalTransactionService::Import::All.new.run

CanonicalEventMapping.create!({
                                canonical_transaction_id: CanonicalTransaction.last.id,
                                event_id: transparent_event.id,
                                user_id: user.id
                              })

# create non-pending transactions for each org

nte_non_pending_transaction = ::RawCsvTransactionService::Create.new(
  unique_bank_identifier: "FSMAIN",
  date: 3.days.ago.iso8601(3),
  memo: "🎤 George Clooney Speaking Fee",
  amount: -892898
).run

::TransactionEngine::HashedTransactionService::RawCsvTransaction::Import.new.run
::TransactionEngine::CanonicalTransactionService::Import::All.new.run

CanonicalEventMapping.create!({
                                canonical_transaction_id: CanonicalTransaction.last.id,
                                event_id: non_transparent_event.id,
                                user_id: user.id
                              })

te_non_pending_transaction = ::RawCsvTransactionService::Create.new(
  unique_bank_identifier: "FSMAIN",
  date: 9.days.ago.iso8601(3),
  memo: "🚢 Cruise Ship Rental",
  amount: -8181
).run

::TransactionEngine::HashedTransactionService::RawCsvTransaction::Import.new.run
::TransactionEngine::CanonicalTransactionService::Import::All.new.run

CanonicalEventMapping.create!({
                                canonical_transaction_id: CanonicalTransaction.last.id,
                                event_id: transparent_event.id,
                                user_id: user.id
                              })

# create pending transactions for each org

nte_non_pending_transaction = CanonicalPendingTransaction.create!(
  date: 4.days.ago,
  memo: "🍷 Wine, lots of wine.",
  amount: -198614
)

CanonicalPendingEventMapping.create!({
                                       canonical_pending_transaction_id: nte_non_pending_transaction.id,
                                       event_id: non_transparent_event.id
                                     })

te_non_pending_transaction = CanonicalPendingTransaction.create!(
  date: 1.days.ago,
  memo: "📋 Overpriced Insurance Policy",
  amount_cents: 140381,
)

CanonicalPendingEventMapping.create!({
                                       canonical_pending_transaction_id: te_non_pending_transaction.id,
                                       event_id: transparent_event.id
                                     })

puts "Done!"
