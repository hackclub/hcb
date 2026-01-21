# frozen_string_literal: true

user = User.first

email = Rails.env.staging? ? "staging@bank.engineering" : "admin@bank.engineering"

if user.nil?
  puts "Woah there, there aren't any users! Creating an user (#{email})."
  user = User.create!(email:, full_name: "Stagey McStageface", phone_number: "+19064225632")
end

puts "Continuing with #{user.email}..."

user.make_admin! unless user.admin?

Governance::Admin::Transfer::Limit.create(user_id: user.id, amount_cents: 1000000000)

system_user = User.create_with(email: User::SYSTEM_USER_EMAIL).create_or_find_by!(id: User::SYSTEM_USER_ID)
system_user.make_admin! unless system_user.admin?

# DEMO
demo_event = Event.create_with(
  name: "DevHacks (Demo Event)",
  slug: "devhacks",
  can_front_balance: true,
  point_of_contact: user,
  demo_mode: true,
  created_at: 7.days.ago
).create_or_find_by!(slug: "devhacks")

OrganizerPositionInvite.create_or_find_by!(
  event: demo_event,
  user:,
  sender: user,
)

# NON_TRANSPARENT
non_transparent_event = Event.create_with(
  name: "ExpensiCon 2023 (Non-Transparent Event)",
  slug: "expensicon23",
  can_front_balance: true,
  point_of_contact: user,
  created_at: 10.days.ago,
  is_public: false
).create_or_find_by!(slug: "expensicon23")

OrganizerPositionInvite.create_or_find_by!(
  event: non_transparent_event,
  user:,
  sender: user,
)

# TRANSPARENT
transparent_event = Event.create_with(
  name: "Hack The Seas (Transparent Event)",
  slug: "hack_the_seas",
  can_front_balance: true,
  point_of_contact: user,
  created_at: 14.days.ago,
  is_public: true
).create_or_find_by!(slug: "hack_the_seas")

OrganizerPositionInvite.create_or_find_by!(
  event: transparent_event,
  user:,
  sender: user,
)

# INCOMING_FEES
incoming_fees_event = Event.create_with(
  name: "Incoming Fees",
  slug: "incoming-fees",
  can_front_balance: true,
  point_of_contact: user,
  created_at: 14.days.ago,
  is_public: false
).create_or_find_by!(id: EventMappingEngine::EventIds::INCOMING_FEES)

incoming_fees_event.plan.update(type: Event::Plan::Internal)

OrganizerPositionInvite.create_or_find_by!(
  event: incoming_fees_event,
  user:,
  sender: user,
)

# HACK_CLUB_BANK
hack_club_bank_event = Event.create_with(
  name: "HCB Operations",
  slug: "bank",
  can_front_balance: true,
  point_of_contact: user,
  created_at: 14.days.ago,
  is_public: true
).create_or_find_by!(id: EventMappingEngine::EventIds::HACK_CLUB_BANK)

hack_club_bank_event.plan.update(type: Event::Plan::HackClubAffiliate)

OrganizerPositionInvite.create_or_find_by!(
  event: hack_club_bank_event,
  user:,
  sender: user,
)

# NOEVENT
noevent_event = Event.create_with(
  name: "Hack Club NoEvent",
  slug: "noevent",
  can_front_balance: true,
  point_of_contact: user,
  created_at: 14.days.ago,
  is_public: false
).create_or_find_by!(id: EventMappingEngine::EventIds::NOEVENT)

noevent_event.plan.update(type: Event::Plan::Internal)

OrganizerPositionInvite.create_or_find_by!(
  event: noevent_event,
  user:,
  sender: user,
)

# HACKATHON_GRANT_FUND
hackathon_grant_fund_event = Event.create_with(
  name: "Hackathon Grant Fund",
  slug: "hackathon-grant-fund",
  can_front_balance: true,
  point_of_contact: user,
  created_at: 14.days.ago,
  is_public: true
).create_or_find_by!(id: EventMappingEngine::EventIds::HACKATHON_GRANT_FUND)

hackathon_grant_fund_event.plan.update(type: Event::Plan::HackClubAffiliate)

OrganizerPositionInvite.create_or_find_by!(
  event: hackathon_grant_fund_event,
  user:,
  sender: user,
)

# WINTER_HARDWARE_WONDERLAND_GRANT_FUND
winter_hardware_wonderland_grant_fund_event = Event.create_with(
  name: "Winter Hardware Wonderland",
  slug: "winter-hardware-wonderland",
  can_front_balance: true,
  point_of_contact: user,
  created_at: 14.days.ago,
  is_public: true
).create_or_find_by!(id: EventMappingEngine::EventIds::WINTER_HARDWARE_WONDERLAND_GRANT_FUND)

winter_hardware_wonderland_grant_fund_event.plan.update(type: Event::Plan::HackClubAffiliate)

OrganizerPositionInvite.create_or_find_by!(
  event: winter_hardware_wonderland_grant_fund_event,
  user:,
  sender: user,
)

# ARGOSY_GRANT_FUND
argosy_grant_fund_event = Event.create_with(
  name: "Argosy Foundation Grant Fund",
  slug: "argosy-foundation-grant",
  can_front_balance: true,
  point_of_contact: user,
  created_at: 14.days.ago,
  is_public: true
).create_or_find_by!(id: EventMappingEngine::EventIds::ARGOSY_GRANT_FUND)

OrganizerPositionInvite.create_or_find_by!(
  event: argosy_grant_fund_event,
  user:,
  sender: user,
)

# ARGOSY_GRANT_FUND_2025
argosy_grant_fund_2025_event = Event.create_with(
  name: "Argosy Foundation Grant Fund",
  slug: "argosy-hardship-rookie-grant-2025-26-season",
  can_front_balance: true,
  point_of_contact: user,
  created_at: 14.days.ago,
  is_public: true
).create_or_find_by!(id: EventMappingEngine::EventIds::ARGOSY_GRANT_FUND_2025)

argosy_grant_fund_2025_event.plan.update(type: Event::Plan::FeeWaived)

OrganizerPositionInvite.create_or_find_by!(
  event: argosy_grant_fund_2025_event,
  user:,
  sender: user,
)

# FIRST_TRANSPARENCY_GRANT_FUND
first_transparency_grant_fund_event = Event.create_with(
  name: "Transparency Grant Fund",
  slug: "transparency-grant-fund",
  can_front_balance: true,
  point_of_contact: user,
  created_at: 14.days.ago,
  is_public: true
).create_or_find_by!(id: EventMappingEngine::EventIds::FIRST_TRANSPARENCY_GRANT_FUND)

first_transparency_grant_fund_event.plan.update(type: Event::Plan::HackClubAffiliate)

OrganizerPositionInvite.create_or_find_by!(
  event: first_transparency_grant_fund_event,
  user:,
  sender: user,
)

# HACK_FOUNDATION_INTEREST
hack_foundation_interest_event = Event.create_with(
  name: "Hack Foundation Interest Earnings",
  slug: "hack-foundation-interest-earnings",
  can_front_balance: true,
  point_of_contact: user,
  created_at: 14.days.ago,
  is_public: true
).create_or_find_by!(id: EventMappingEngine::EventIds::HACK_FOUNDATION_INTEREST)

hack_foundation_interest_event.plan.update(type: Event::Plan::HackClubAffiliate)

OrganizerPositionInvite.create_or_find_by!(
  event: hack_foundation_interest_event,
  user:,
  sender: user,
)

# REIMBURSEMENT_CLEARING
reimbursement_clearing_event = Event.create_with(
  name: "HCB Reimbursement Clearinghouse",
  slug: "reimbursement-clearinghouse",
  can_front_balance: true,
  point_of_contact: user,
  created_at: 14.days.ago,
  is_public: true
).create_or_find_by!(id: EventMappingEngine::EventIds::REIMBURSEMENT_CLEARING)

reimbursement_clearing_event.plan.update(type: Event::Plan::Internal)

OrganizerPositionInvite.create_or_find_by!(
  event: reimbursement_clearing_event,
  user:,
  sender: user,
)

# SVB_SWEEPS
svb_sweeps_event = Event.create_with(
  name: "HCB Sweeps",
  slug: "hcb-sweeps",
  can_front_balance: true,
  point_of_contact: user,
  created_at: 14.days.ago,
  is_public: true
).create_or_find_by!(id: EventMappingEngine::EventIds::SVB_SWEEPS)

svb_sweeps_event.plan.update(type: Event::Plan::Internal)

OrganizerPositionInvite.create_or_find_by!(
  event: svb_sweeps_event,
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
