# frozen_string_literal: true

user = User.first

email = Rails.env.staging? ? "staging@bank.engineering" : "admin@bank.engineering"

if user.nil?
  puts "Woah there, there aren't any users! Creating an user (#{email})."
  user = User.create!(email:, full_name: "Stagey McStageface", phone_number: "+19064225632", verified: true)
end

puts "Continuing with #{user.email}..."

user.make_admin! unless user.admin?

Governance::Admin::Transfer::Limit.create(user_id: user.id, amount_cents: 1000000000)

system_user = User.create_with(email: User::SYSTEM_USER_EMAIL, verified: true).create_or_find_by!(id: User::SYSTEM_USER_ID)
system_user.make_admin! unless system_user.admin?

# DEMO
demo_event = Event.create_with(
  name: "DevHacks (Demo Event)",
  slug: "devhacks",
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

# GENE_HAAS_GRANT_FUND
gene_haas_grant_fund_event = Event.create_with(
  name: "Gene Haas",
  slug: "gene-haas",
  point_of_contact: user,
  created_at: 14.days.ago,
  is_public: true
).create_or_find_by!(id: EventMappingEngine::EventIds::GENE_HAAS_GRANT_FUND)

OrganizerPositionInvite.create_or_find_by!(
  event: gene_haas_grant_fund_event,
  user:,
  sender: user,
)

# ARGOSY_GRANT_FUND
argosy_grant_fund_event = Event.create_with(
  name: "Argosy Foundation Grant Fund",
  slug: "argosy-foundation-grant",
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

# Raw CSV transactions carry nothing (a linked object, a Column account number,
# a Stripe card) that Ledger::Mapper can use to work out their event, so their
# ledger items would never land on a ledger and every balance would read zero.
# Map them the way an admin maps a transaction by hand (see
# AdminController#set_event).
map_to_ledger = lambda do |ledger_item, event|
  ledger = Ledger.find_or_create_by!(primary: true, event:)
  Ledger::Mapping.map_primary!(ledger:, ledger_item:, mapped_by: user)
end

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
map_to_ledger.call(CanonicalTransaction.last.ledger_item, non_transparent_event)

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
map_to_ledger.call(CanonicalTransaction.last.ledger_item, transparent_event)

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
map_to_ledger.call(CanonicalTransaction.last.ledger_item, non_transparent_event)

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
map_to_ledger.call(CanonicalTransaction.last.ledger_item, transparent_event)

# create pending transactions for each org
#
# These are checks still awaiting admin approval, which keeps them pending.
# A pending transaction needs a real source like this: a bare
# CanonicalPendingTransaction gets an HCB-000-<id> code, the same code as the
# CSV transaction above with that id, so the two would be grouped together and
# the pending amount would hide inside an unrelated settled transaction.

non_transparent_event.increase_checks.create!(
  user:,
  amount: 19861400,
  memo: "🍷 Wine, lots of wine.",
  payment_for: "🍷 Wine, lots of wine.",
  recipient_name: "Bacchus Fine Wines",
  recipient_email: "orders@example.com",
  address_line1: "1 Vineyard Way",
  address_city: "Napa",
  address_state: "CA",
  address_zip: "94558",
  created_at: 4.days.ago
)

transparent_event.increase_checks.create!(
  user:,
  amount: 140381,
  memo: "📋 Overpriced Insurance Policy",
  payment_for: "📋 Overpriced Insurance Policy",
  recipient_name: "Overpriced Insurance Co.",
  recipient_email: "billing@example.com",
  address_line1: "100 Premium Street",
  address_city: "Hartford",
  address_state: "CT",
  address_zip: "06103",
  created_at: 1.day.ago
)

puts "Done!"
