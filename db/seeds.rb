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

# GENE_HAAS_GRANT_FUND
gene_haas_grant_fund_event = Event.create_with(
  name: "Gene Haas",
  slug: "gene-haas",
  can_front_balance: true,
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
  date: 1.day.ago,
  memo: "📋 Overpriced Insurance Policy",
  amount_cents: 140381,
)

CanonicalPendingEventMapping.create!({
                                       canonical_pending_transaction_id: te_non_pending_transaction.id,
                                       event_id: transparent_event.id
                                     })

# ============================================================================
# EXTENSIVE DEVELOPMENT SEED DATA
#
# Everything below builds realistic, fully-fictional demo data that exercises
# every major surface of the app: organizations, sub-organizations, members,
# donations, invoices, transfers (ACH/check/wire/PayPal/Wise), disbursements,
# cards & card grants, reimbursements, contractors, payroll, employees, tax
# forms, admin review queues, and general engagement (comments, tags,
# announcements, receipts). None of it is copied from production.
#
# It is written to run offline (`rails db:seed`): callbacks that would hit
# external services (Stripe, Column, Wise, DocuSeal, TaxBandits) are skipped or
# side-stepped, and transfers are advanced with their AASM events rather than
# their network-backed senders. It is designed to run on a freshly prepared
# database (`rails db:setup` / `db:reset`); each org's rich data is guarded so it
# is generated only once even if the section runs again.
# ============================================================================

require "stringio"

Faker::Config.random = Random.new(0) # deterministic, reproducible fake data
admin = user

# Callbacks that would reach Stripe in development (only stubbed in test env).
Donation.skip_callback(:create, :before, :create_stripe_payment_intent, raise: false)
Sponsor.skip_callback(:create, :before, :create_stripe_customer, raise: false)
Sponsor.skip_callback(:update, :before, :update_stripe_customer, raise: false)

def seed_person(email, full_name)
  User.create_with(full_name:, verified: true).find_or_create_by!(email:)
end

def seed_org(slug, name, **attrs)
  event = Event.create_with(name:, point_of_contact: User.first, can_front_balance: true, **attrs).find_or_create_by!(slug:)
  OrganizerPositionInvite.find_or_create_by!(event:, user: User.first, sender: User.first)
  event
end

def seed_member(event, member, role, sender)
  return if OrganizerPosition.exists?(event:, user: member)

  invite = OrganizerPositionInvite.create!(event:, user: member, sender:, role:)
  invite.accept unless invite.accepted? # self-invites auto-accept via callback
end

def seed_tag(event, name)
  tag = EventTag.find_or_create_by!(name:)
  event.event_tags << tag unless event.event_tags.include?(tag)
end

# Creates a settled canonical transaction and maps it to the event. Positive
# cents = money in, negative = money out. Returns the CanonicalTransaction.
def seed_settled(event, memo, amount_cents, date)
  # RawCsvTransactionService takes a dollar amount (it monetizes into cents); seed amounts are whole dollars.
  ::RawCsvTransactionService::Create.new(unique_bank_identifier: "FSMAIN", date: date.iso8601(3), memo:, amount: amount_cents / 100).run
  ::TransactionEngine::HashedTransactionService::RawCsvTransaction::Import.new.run
  ::TransactionEngine::CanonicalTransactionService::Import::All.new.run
  ct = CanonicalTransaction.last
  CanonicalEventMapping.create!(canonical_transaction_id: ct.id, event_id: event.id, user_id: User.first.id)
  ct
end

# Donation -> fronted pending transaction on the org ledger.
def seed_donation(event, amount_cents, name:, email:, created_at:, recurring: nil, anonymous: false, in_person: false)
  donation = Donation.new(event:, amount: amount_cents, status: "succeeded", created_at:, anonymous:, in_person:)
  if recurring
    donation.recurring_donation = recurring
  else
    donation.name = name
    donation.email = email
    donation.url_hash = SecureRandom.hex(8)
    donation.stripe_payment_intent_id = "pi_seed_#{SecureRandom.hex(8)}"
  end
  donation.save!
  donation.mark_in_transit!

  rpdt = ::PendingTransactionEngine::RawPendingDonationTransactionService::Donation::ImportSingle.new(donation:).run
  cpt = ::PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::Donation.new(raw_pending_donation_transaction: rpdt).run
  ::PendingEventMappingEngine::Map::Single::Donation.new(canonical_pending_transaction: cpt).run
  donation
end

def seed_receipt(receiptable, uploader)
  Receipt.create!(receiptable:, user: uploader, upload_method: :transaction_page,
                  file: { io: StringIO.new("seed,receipt\n#{receiptable.class.name},#{Time.now.to_i}\n"), filename: "receipt-#{SecureRandom.hex(4)}.csv", content_type: "text/csv" })
end

def seed_populated?(event)
  event.canonical_transactions.exists? || event.canonical_pending_transactions.exists? || event.donations.exists?
end

# Gives a user a default ACH payout method (required to submit reimbursements).
def seed_payout_method(person)
  le = person.personal_legal_entity
  return if le.nil? || le.default_payout_method

  LegalEntity::PayoutMethod.create!(legal_entity: le, default: true,
                                    details: LegalEntity::PayoutMethod::AchTransfer.new(account_number: "123456789", routing_number: "021000021"))
end

# ---- shared cast of fictional people --------------------------------------
maya      = seed_person("maya.organizer@example.com", "Maya Rodriguez")
devon     = seed_person("devon.member@example.com", "Devon Clarke")
priya     = seed_person("priya.reader@example.com", "Priya Nair")
contractor_user = seed_person("sam.contractor@example.com", "Sam Whitfield")
auditor = seed_person("audrey.auditor@example.com", "Audrey Lin")
auditor.update!(access_level: :auditor) unless auditor.auditor?

# ===========================================================================
# 1. FLAGSHIP ORG — every feature exercised
# ===========================================================================
flagship = seed_org("bay-area-hacks", "Bay Area Hacks", is_public: true)
flagship.plan.update(type: Event::Plan::Standard.name) unless flagship.plan.is_a?(Event::Plan::Standard)
seed_member(flagship, maya, :manager, admin)
seed_member(flagship, devon, :member, admin)
seed_member(flagship, priya, :reader, admin)
seed_tag(flagship, EventTag::Tags::HACKATHON)
seed_tag(flagship, EventTag::Tags::ORGANIZED_BY_HACK_CLUBBERS)

unless seed_populated?(flagship)
  # -- funding (settled starting balance) --
  grant_ct = seed_settled(flagship, "🏦 Founding grant from The Hack Foundation", 8_000_000, 20.days.ago)
  seed_settled(flagship, "🏦 Corporate match — GitHub", 1_500_000, 15.days.ago)

  # editable memo + comment + tag + receipt on a real transaction
  grant_ct.update!(custom_memo: "Initial program funding")
  grant_hcb = grant_ct.local_hcb_code
  Comment.create!(commentable: grant_hcb, user: maya, content: "Confirmed receipt with the foundation. 🎉")
  Tag.create!(event: flagship, label: "Food", emoji: "🍕", color: "orange")
  travel_tag = Tag.create!(event: flagship, label: "Travel", emoji: "🚌", color: "blue")
  grant_hcb.tags << travel_tag
  seed_receipt(grant_hcb, maya)

  # -- donations: one-off, anonymous, in-person, min & large, recurring --
  seed_donation(flagship, 5_000, name: "Jane Donor", email: "jane.donor@gmail.com", created_at: 12.days.ago)
  seed_donation(flagship, 100, name: "Penny Pincher", email: "penny@gmail.com", created_at: 11.days.ago) # $1 minimum
  seed_donation(flagship, 2_500_00, name: "Big Backer", email: "big.backer@gmail.com", created_at: 10.days.ago)
  seed_donation(flagship, 7_500, name: "Anonymous", email: "anon.donor@gmail.com", created_at: 9.days.ago, anonymous: true)
  seed_donation(flagship, 4_000, name: "Cash Donor", email: "cash@gmail.com", created_at: 8.days.ago, in_person: true)

  recurring = RecurringDonation.new(event: flagship, name: "Monthly Mary", email: "mary.monthly@gmail.com", amount: 2_500, stripe_status: "active")
  recurring.stripe_subscription_id = "sub_seed_#{SecureRandom.hex(8)}"
  recurring.stripe_customer_id = "cus_seed_#{SecureRandom.hex(8)}"
  recurring.save!
  seed_donation(flagship, recurring.amount, name: nil, email: nil, created_at: 6.days.ago, recurring:)

  # refunded & failed donations (edge states, no ledger entry)
  refunded = Donation.new(event: flagship, amount: 3_000, status: "succeeded", created_at: 7.days.ago, name: "Regretful Rita", email: "rita@gmail.com", url_hash: SecureRandom.hex(8), stripe_payment_intent_id: "pi_seed_#{SecureRandom.hex(8)}")
  refunded.save!
  refunded.mark_in_transit!
  refunded.mark_refunded!
  failed = Donation.new(event: flagship, amount: 6_000, status: "failed", created_at: 5.days.ago, name: "Bounced Bob", email: "bob@gmail.com", url_hash: SecureRandom.hex(8), stripe_payment_intent_id: "pi_seed_#{SecureRandom.hex(8)}")
  failed.save!
  failed.mark_failed!

  # -- sponsor + invoices (open, paid-on-ledger, manually paid, void) --
  sponsor = flagship.sponsors.create!(name: "Globex Corporation", contact_email: "ap@globex.example.com",
                                      address_line1: "500 Market St", address_city: "San Francisco", address_state: "CA",
                                      address_postal_code: "94105", address_country: "US", stripe_customer_id: "cus_seed_#{SecureRandom.hex(8)}")

  Invoice.create!(sponsor:, creator: admin, item_description: "Platinum event sponsorship", item_amount: 2_500_00,
                  due_date: 14.days.from_now, status: "open", amount_due: 2_500_00, amount_remaining: 2_500_00, amount_paid: 0,
                  subtotal: 2_500_00, total: 2_500_00, stripe_invoice_id: "in_seed_#{SecureRandom.hex(10)}", item_stripe_id: "ii_seed_#{SecureRandom.hex(10)}", auto_advance: false)

  paid_invoice = Invoice.create!(sponsor:, creator: admin, item_description: "Gold sponsorship", item_amount: 1_000_00,
                                 due_date: 7.days.from_now, status: "paid", amount_due: 1_000_00, amount_paid: 1_000_00, amount_remaining: 0,
                                 subtotal: 1_000_00, total: 1_000_00, stripe_invoice_id: "in_seed_#{SecureRandom.hex(10)}", item_stripe_id: "ii_seed_#{SecureRandom.hex(10)}", auto_advance: false)
  paid_invoice.mark_paid!
  paid_rpit = RawPendingInvoiceTransaction.create!(invoice_transaction_id: paid_invoice.id.to_s, amount_cents: paid_invoice.amount_paid, date_posted: 2.days.ago)
  paid_cpt = CanonicalPendingTransaction.create!(date: paid_rpit.date, memo: paid_rpit.memo, amount_cents: paid_rpit.amount_cents, raw_pending_invoice_transaction_id: paid_rpit.id, fronted: true, fee_waived: false)
  CanonicalPendingEventMapping.create!(canonical_pending_transaction_id: paid_cpt.id, event_id: flagship.id)

  manual_invoice = Invoice.create!(sponsor:, creator: admin, item_description: "Silver sponsorship (paid by check)", item_amount: 500_00,
                                   due_date: 5.days.from_now, status: "paid", amount_due: 500_00, amount_paid: 500_00, amount_remaining: 0,
                                   subtotal: 500_00, total: 500_00, stripe_invoice_id: "in_seed_#{SecureRandom.hex(10)}", item_stripe_id: "ii_seed_#{SecureRandom.hex(10)}", auto_advance: false)
  manual_invoice.update!(manually_marked_as_paid_at: 1.day.ago, manually_marked_as_paid_user: admin, manually_marked_as_paid_reason: "Received a mailed check")
  manual_invoice.mark_paid!

  Invoice.create!(sponsor:, creator: admin, item_description: "Bronze sponsorship (cancelled)", item_amount: 250_00,
                  due_date: 10.days.from_now, status: "void", amount_due: 250_00, amount_remaining: 250_00, amount_paid: 0,
                  subtotal: 250_00, total: 250_00, stripe_invoice_id: "in_seed_#{SecureRandom.hex(10)}", item_stripe_id: "ii_seed_#{SecureRandom.hex(10)}", auto_advance: false).mark_void!

  # -- cards: cardholder, virtual card, card spend, a frozen card --
  cardholder = StripeCardholder.create!(user: maya, stripe_id: "ich_seed_#{maya.id}", cardholder_type: :individual, stripe_name: maya.name, stripe_email: maya.email)
  card = StripeCard.new(event: flagship, stripe_cardholder: cardholder, card_type: :virtual, stripe_id: "ic_seed_#{SecureRandom.hex(4)}",
                        stripe_brand: "Visa", stripe_exp_month: 12, stripe_exp_year: 2030, last4: "4242", stripe_status: "active", initially_activated: true, name: "Maya's Card")
  card.skip_notify_user = true
  card.save!
  frozen_card = StripeCard.new(event: flagship, stripe_cardholder: cardholder, card_type: :virtual, stripe_id: "ic_seed_#{SecureRandom.hex(4)}",
                               stripe_brand: "Visa", stripe_exp_month: 6, stripe_exp_year: 2029, last4: "1010", stripe_status: "inactive", initially_activated: true, name: "Frozen Card")
  frozen_card.skip_notify_user = true
  frozen_card.save!

  [["SkyLab Cloud Hosting", 25_99, "computer_software_stores"], ["Blue Bottle Coffee", 8_40, "eating_places_restaurants"], ["Amtrak", 120_00, "transportation_services"]].each do |merchant, cents, category|
    auth_id = "iauth_seed_#{SecureRandom.hex(6)}"
    rpst = RawPendingStripeTransaction.create!(stripe_transaction_id: auth_id, amount_cents: -cents, date_posted: rand(1..9).days.ago,
                                               stripe_transaction: { "id" => auth_id, "status" => "pending", "created" => Time.now.to_i, "authorization_method" => "online", "amount" => cents, "pending_request" => { "amount" => cents }, "card" => { "id" => card.stripe_id }, "merchant_data" => { "name" => merchant, "network_id" => rand(10**9).to_s, "category" => category } })
    charge_cpt = CanonicalPendingTransaction.create!(raw_pending_stripe_transaction: rpst, amount_cents: -cents, date: rpst.date_posted, memo: merchant)
    CanonicalPendingEventMapping.create!(canonical_pending_transaction_id: charge_cpt.id, event_id: flagship.id, subledger_id: card.subledger_id)
  end

  # -- card grant (issues an internal disbursement to a subledger) --
  card_grant = CardGrant.create!(event: flagship, sent_by: admin, email: "grantee@example.com", amount_cents: 250_00, purpose: "Travel stipend")
  grant_card = StripeCard.new(event: flagship, stripe_cardholder: cardholder, card_type: :virtual, subledger: card_grant.subledger, stripe_id: "ic_grant_#{SecureRandom.hex(4)}",
                              stripe_brand: "Visa", stripe_exp_month: 12, stripe_exp_year: 2030, last4: "3333", stripe_status: "active", initially_activated: true, name: "Grant Card")
  grant_card.skip_notify_user = true
  grant_card.save!
  card_grant.update!(stripe_card: grant_card)

  # -- outgoing transfers: ACH, check, wire, PayPal, Wise --
  ach = AchTransfer.create!(event: flagship, creator: admin, amount: 250_00, routing_number: "110000000", account_number: "000123456789",
                            bank_name: "Seed Bank", recipient_name: "Jane Vendor", recipient_email: "jane.vendor@example.com", payment_for: "Venue deposit")
  ach.mark_in_transit!
  ach.mark_deposited!
  ach.update_column(:column_id, "acht_seed_#{SecureRandom.hex(6)}")

  check = IncreaseCheck.create!(event: flagship, user: admin, amount: 100_00, memo: "Prize payout", payment_for: "Hackathon prize",
                                recipient_name: "Winning Team", recipient_email: "winner@example.com", address_line1: "123 Main St", address_line2: "",
                                address_city: "West Hollywood", address_state: "CA", address_zip: "90069")
  check.mark_approved!

  # Wire validation performs Column bank-country lookups; skip them (still fronts a pending txn).
  Wire.new(event: flagship, user: admin, amount_cents: 500_00, currency: "USD", memo: "Intl vendor payment", payment_for: "Merch printing",
           recipient_name: "Global Print Ltd", recipient_email: "ap@globalprint.example", account_number: "DE89370400440532013000", bic_code: "DEUTDEFF",
           address_line1: "10 Alexanderplatz", address_line2: "", address_city: "Berlin", address_state: "BE", address_postal_code: "10178", recipient_country: "DE").save!(validate: false)

  # PayPal transfers can't be validated (model blocks new ones); create unvalidated, leave pending.
  PaypalTransfer.new(event: flagship, user: admin, amount_cents: 75_00, memo: "Speaker honorarium", payment_for: "Keynote", recipient_name: "Alex Speaker", recipient_email: "alex.speaker@example.com").save!(validate: false)

  WiseTransfer.create!(event: flagship, user: admin, amount_cents: 300_00, currency: "EUR", quoted_usd_amount_cents: 330_00, usd_amount_cents: 330_00,
                       payment_for: "Contractor", recipient_name: "Marie Dev", recipient_email: "marie.dev@example.com", recipient_country: "FR",
                       address_line1: "5 Rue de Rivoli", address_city: "Paris", address_state: "IDF", address_postal_code: "75001")

  # -- incoming check deposit --
  png = "\x89PNG\r\n\x1a\n".b + SecureRandom.bytes(64)
  deposit = CheckDeposit.new(event: flagship, created_by: admin, amount_cents: 400_00)
  deposit.front.attach(io: StringIO.new(png), filename: "front.png", content_type: "image/png")
  deposit.back.attach(io: StringIO.new(png), filename: "back.png", content_type: "image/png")
  deposit.save!

  # -- contractor: payee + tax form + payment + payroll + signed contract --
  contractor_le = contractor_user.personal_legal_entity
  Tax::Form.create!(legal_entity: contractor_le, external_service: :manual, aasm_state: :completed, entity_type: :person, sent_at: 3.days.ago, completed_at: 2.days.ago)
  payee = Payee.create!(event: flagship, legal_entity: contractor_le, display_name: contractor_user.name, email: contractor_user.email)
  Payment.create!(payee:, creator: admin, amount_cents: 250_00, currency: "USD", purpose: "Logo design", aasm_state: "successful", sent_at: 2.days.ago, successful_at: 1.day.ago)

  position = Payroll::Position.create!(payee:, title: "Backend Engineer", description: "API work for the fall program", rate_cents: 8_500, currency: "USD", rate_unit: "hour", start_date: Date.current, end_date: 3.months.from_now, aasm_state: "onboarded")
  payroll_invoice = Payroll::Invoice.create!(payroll_position: position, amount_cents: 500_00, currency: "USD", name: "October hours", aasm_state: "approved", approved_at: 1.day.ago)
  payroll_payment = Payment.create!(payee:, creator: admin, amount_cents: payroll_invoice.amount_cents, currency: "USD", purpose: payroll_invoice.name, aasm_state: "successful", sent_at: 2.hours.ago, successful_at: 1.hour.ago)
  payroll_invoice.update!(payment: payroll_payment)

  # Build the contract in `pending` (so its auto hcb party is allowed), add parties, then
  # settle the signed state without firing DocuSeal/onboarding callbacks.
  contract = Contract::PayrollPosition.create!(contractable: position, external_service: :manual, include_videos: false)
  contract.parties.create!(user: admin, role: :organizer)
  contract.parties.create!(external_email: payee.email, role: :contractor)
  contract.parties.update_all(aasm_state: "signed", signed_at: 1.day.ago)
  contract.update_columns(aasm_state: "signed", signed_at: 1.day.ago)
  seed_payout_method(contractor_user) # after payments settle, so no Column call

  # -- employee (Gusto-style) payroll --
  employee = Employee.create!(event: flagship, entity: devon, aasm_state: "onboarded", gusto_id: "gusto_seed_#{SecureRandom.hex(4)}")
  Employee::Payment.create!(employee:, title: "Salary — October", amount_cents: 3_000_00, aasm_state: "paid", reviewed_by: admin, approved_at: 1.day.ago)

  # -- reimbursement report (full lifecycle to reimbursed) --
  seed_payout_method(maya)
  report = Reimbursement::Report.create!(user: maya, event: flagship, name: "Conference travel")
  expense = report.expenses.create!(value: 42.50, memo: "Taxi from airport", category: "Travel")
  seed_receipt(expense, maya)
  report.expenses.create!(value: 18.75, memo: "Team lunch", category: "Food & Entertainment").tap { |e| seed_receipt(e, maya) }
  report.mark_submitted!
  if report.reload.submitted?
    report.expenses.pending.each(&:mark_approved!)
    report.mark_reimbursement_requested!
  end
  report.mark_reimbursement_approved!

  # a rejected reimbursement (edge state)
  rejected_report = Reimbursement::Report.create!(user: maya, event: flagship, name: "Unapproved gadget")
  rejected_report.expenses.create!(value: 99.00, memo: "Drone", category: "Equipment & Furniture").tap { |e| seed_receipt(e, maya) }
  rejected_report.mark_submitted! if rejected_report.may_mark_submitted?
  rejected_report.mark_rejected!

  # -- engagement: announcement + document --
  Announcement.create!(event: flagship, author: admin, title: "Welcome to Bay Area Hacks!",
                       content: { type: "doc", content: [{ type: "paragraph", content: [{ type: "text", text: "Our finances are now live on HCB. Reach out to an organizer with any questions." }] }] },
                       aasm_state: :draft)
  bylaws = Document.new(user: admin, event: flagship, name: "Organization Bylaws", category: :forms)
  bylaws.file.attach(io: StringIO.new("Seed bylaws document."), filename: "bylaws.txt", content_type: "text/plain")
  bylaws.save!

  # -- a member requests removal (admin review queue) --
  OrganizerPositionDeletionRequest.create!(organizer_position: OrganizerPosition.find_by(event: flagship, user: priya), submitted_by: priya, reason: "No longer involved with the team.")
end

# ===========================================================================
# 2. SUB-ORGANIZATION + disbursement from the flagship parent
# ===========================================================================
suborg = seed_org("bay-area-hacks-south-bay", "Bay Area Hacks — South Bay Chapter", is_public: true, parent: flagship)
seed_member(suborg, devon, :manager, admin)
unless seed_populated?(suborg)
  DisbursementService::Create.new(source_event_id: flagship.id, destination_event_id: suborg.id,
                                  name: "Seed funding for South Bay chapter", amount: "1500.00", requested_by_id: admin.id, fronted: true).run
end

# ===========================================================================
# 3. ROBOTICS TEAM — moderate data, different plan/tags
# ===========================================================================
robotics = seed_org("team-8032-robotics", "Team 8032 Robotics", is_public: true)
robotics.plan.update(type: Event::Plan::FeeWaived.name) unless robotics.plan.is_a?(Event::Plan::FeeWaived)
seed_member(robotics, priya, :manager, admin)
seed_tag(robotics, EventTag::Tags::ROBOTICS_TEAM)
unless seed_populated?(robotics)
  seed_settled(robotics, "🏦 School district grant", 1_200_000, 18.days.ago)
  seed_settled(robotics, "🔧 Machine shop supplies", -85_000, 6.days.ago)
  seed_donation(robotics, 15_000, name: "Robotics Booster", email: "booster@gmail.com", created_at: 9.days.ago)
  seed_donation(robotics, 5_000, name: "Alumni Fund", email: "alumni@gmail.com", created_at: 4.days.ago)
  check = IncreaseCheck.create!(event: robotics, user: admin, amount: 300_00, memo: "Competition registration", payment_for: "FRC regional",
                                recipient_name: "FIRST Robotics", recipient_email: "reg@example.com", address_line1: "200 Bedford St", address_line2: "",
                                address_city: "Manchester", address_state: "NH", address_zip: "03101")
  check.mark_approved!
end

# ===========================================================================
# 4. EDGE CASE — financially frozen, high risk, mixed pending activity
# ===========================================================================
frozen_org = seed_org("frozen-assets-collective", "Frozen Assets Collective", is_public: false)
frozen_org.plan.update(type: Event::Plan::FeeWaived.name) unless frozen_org.plan.is_a?(Event::Plan::FeeWaived)
unless seed_populated?(frozen_org)
  seed_settled(frozen_org, "🏦 Initial deposit", 500_000, 30.days.ago)
  seed_donation(frozen_org, 10_000, name: "Concerned Citizen", email: "citizen@gmail.com", created_at: 12.days.ago)
  pending = CanonicalPendingTransaction.create!(date: 2.days.ago, memo: "❄️ Suspicious purchase under review", amount_cents: -75_000)
  CanonicalPendingEventMapping.create!(canonical_pending_transaction_id: pending.id, event_id: frozen_org.id)
end
frozen_org.update!(financially_frozen: true, risk_level: :high) unless frozen_org.financially_frozen?

# ===========================================================================
# 5. EDGE CASE — brand-new empty org (tests empty states)
# ===========================================================================
fresh = seed_org("fresh-start-hacks", "Fresh Start Hacks", is_public: true)
seed_member(fresh, maya, :manager, admin)

# ===========================================================================
# 6. EDGE CASE — overdrawn org (negative balance)
# ===========================================================================
overdrawn = seed_org("overdrawn-outpost", "Overdrawn Outpost", is_public: false)
unless seed_populated?(overdrawn)
  seed_settled(overdrawn, "🏦 Small starting grant", 50_000, 14.days.ago)
  seed_settled(overdrawn, "💸 Emergency equipment purchase", -120_000, 3.days.ago)
end

# ===========================================================================
# 7. ADMIN REVIEW QUEUE — a pending fiscal sponsorship application
# ===========================================================================
Event::Application.create_with(
  description: "A new competitive programming club looking for fiscal sponsorship.",
  address_line1: "1 Main St", address_city: "Burlington", address_state: "VT",
  address_postal_code: "05401", address_country: "US", aasm_state: :under_review,
  submitted_at: 2.days.ago, under_review_at: 1.day.ago, teen_led: true
).find_or_create_by!(user: maya, name: "Algorithms Club")

# ===========================================================================
# 8. MISC ENGAGEMENT — raffle, referral program, event group
# ===========================================================================
Raffle.find_or_create_by!(user: maya, program: "first-worlds-2026-macbook")
referral_program = Referral::Program.find_or_create_by!(name: "FIRST 2026 Referrals", creator: admin)
Referral::Link.create_with(name: "Homepage banner").find_or_create_by!(program: referral_program, creator: admin)
Event::Group.find_or_create_by!(name: "My Demo Orgs", user: admin)

puts "Done!"
