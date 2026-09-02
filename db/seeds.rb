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
# Builds a large, realistic, fully-fictional dataset (nothing copied from
# production) so a development database exercises every major surface of the
# app with plenty of volume: organizations & sub-orgs, members, donations,
# invoices, transfers (ACH/check/wire/PayPal/Wise), disbursements, cards & card
# grants, reimbursements, contractors, payroll, employees, tax forms, admin
# review queues, receipts, comments, tags, announcements and documents.
#
# The signed-in admin (`User.first`) is woven in as a real participant of the
# showcased events so their own cards, card grants, receipts, reimbursements and
# payout methods are populated.
#
# Runs offline: in development the Stripe/Column fake-key fallbacks only apply in
# the test env, so callbacks that would reach external services (Stripe, Column,
# Wise, DocuSeal, TaxBandits) are skipped or side-stepped, and transfers are
# advanced with their AASM events rather than their network-backed senders. Jobs
# are enqueued to the test adapter so no async side effects fire. Designed for the
# standard `rails db:setup` / `db:reset` flow; each event's rich data is guarded
# so it is generated only once.
# ============================================================================

require "stringio"

Faker::Config.random = Random.new(0)                  # deterministic fake data
ActiveJob::Base.queue_adapter = :test                 # enqueue only; no async side effects
admin = user

# Callbacks that would reach Stripe in development (only stubbed in test env).
Donation.skip_callback(:create, :before, :create_stripe_payment_intent, raise: false)
Sponsor.skip_callback(:create, :before, :create_stripe_customer, raise: false)
Sponsor.skip_callback(:update, :before, :update_stripe_customer, raise: false)

# Real ABA routing numbers (Chase, BofA, Wells Fargo, US Bank, PNC, Citi, TD...).
REAL_ROUTING_NUMBERS = %w[021000021 026009593 121042882 091000022 043000096 021000089 031201360 111000025 122105155 322271627].freeze
EMAIL_DOMAINS = %w[gmail.com outlook.com yahoo.com icloud.com hotmail.com proton.me].freeze
CARD_MERCHANTS = [
  ["Amazon Web Services", "computer_software_stores"], ["GitHub", "computer_software_stores"],
  ["Delta Air Lines", "airlines_air_carriers"], ["Amtrak", "transportation_services"],
  ["Uber", "taxicabs_limousines"], ["Blue Bottle Coffee", "eating_places_restaurants"],
  ["Chipotle", "eating_places_restaurants"], ["Target", "discount_stores"],
  ["Home Depot", "home_supply_warehouse_stores"], ["Adafruit", "electronics_stores"],
  ["DigiKey", "electronics_stores"], ["Notion Labs", "computer_software_stores"],
  ["Figma", "computer_software_stores"], ["Zoom", "computer_software_stores"],
  ["Marriott", "lodging"], ["Costco", "wholesale_clubs"]
].freeze

def fake_name
  "#{Faker::Name.first_name.gsub(/[^A-Za-z]/, '')} #{Faker::Name.last_name.gsub(/[^A-Za-z]/, '')}"
end

def fake_email(seed = SecureRandom.hex(3))
  "#{seed.downcase.gsub(/[^a-z0-9]+/, '.')}@#{EMAIL_DOMAINS.sample}"
end

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
  invite.accept unless invite.accepted?
end

def seed_tag(event, name)
  tag = EventTag.find_or_create_by!(name:)
  event.event_tags << tag unless event.event_tags.include?(tag)
end

# Settled canonical transaction mapped to the event. RawCsvTransactionService takes
# a dollar amount (whole dollars here); positive = money in, negative = money out.
def seed_settled(event, memo, amount_cents, date)
  ::RawCsvTransactionService::Create.new(unique_bank_identifier: "FSMAIN", date: date.iso8601(3), memo:, amount: amount_cents / 100).run
  ::TransactionEngine::HashedTransactionService::RawCsvTransaction::Import.new.run
  ::TransactionEngine::CanonicalTransactionService::Import::All.new.run
  ct = CanonicalTransaction.last
  CanonicalEventMapping.create!(canonical_transaction_id: ct.id, event_id: event.id, user_id: User.first.id)
  ct
end

def fake_receipt_file
  case %i[png pdf csv].sample
  when :png then { io: StringIO.new("\x89PNG\r\n\x1a\n".b + SecureRandom.bytes(48)), filename: "receipt-#{SecureRandom.hex(3)}.png", content_type: "image/png" }
  when :pdf then { io: StringIO.new("%PDF-1.4\n% seed receipt\n"), filename: "receipt-#{SecureRandom.hex(3)}.pdf", content_type: "application/pdf" }
  else { io: StringIO.new("item,amount\nSeed item,#{rand(1..500)}\n"), filename: "receipt-#{SecureRandom.hex(3)}.csv", content_type: "text/csv" }
  end
end

def seed_receipt(receiptable, uploader)
  Receipt.create!(receiptable:, user: uploader, upload_method: :transaction_page, file: fake_receipt_file)
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

def seed_sponsor(event, name)
  event.sponsors.create!(name:, contact_email: fake_email(name), address_line1: Faker::Address.street_address,
                         address_city: "San Francisco", address_state: "CA", address_postal_code: "94105",
                         address_country: "US", stripe_customer_id: "cus_seed_#{SecureRandom.hex(8)}")
end

def seed_invoice(event, sponsor, creator, description, cents, state)
  paid = %i[paid manual].include?(state)
  invoice = Invoice.create!(sponsor:, creator:, item_description: description, item_amount: cents,
                            due_date: rand(3..30).days.from_now, status: (if state == :void
                                                                            "void"
                                                                          else
                                                                            state == :open ? "open" : "paid"
                                                                          end),
                            amount_due: cents, amount_paid: (paid ? cents : 0), amount_remaining: (paid ? 0 : cents),
                            subtotal: cents, total: cents, stripe_invoice_id: "in_seed_#{SecureRandom.hex(10)}",
                            item_stripe_id: "ii_seed_#{SecureRandom.hex(10)}", auto_advance: false)
  case state
  when :void
    invoice.mark_void!
  when :manual
    invoice.update!(manually_marked_as_paid_at: rand(1..10).days.ago, manually_marked_as_paid_user: creator, manually_marked_as_paid_reason: "Paid via mailed check")
    invoice.mark_paid!
  when :paid
    invoice.mark_paid!
    rpit = RawPendingInvoiceTransaction.create!(invoice_transaction_id: invoice.id.to_s, amount_cents: invoice.amount_paid, date_posted: rand(1..10).days.ago)
    cpt = CanonicalPendingTransaction.create!(date: rpit.date, memo: rpit.memo, amount_cents: rpit.amount_cents, raw_pending_invoice_transaction_id: rpit.id, fronted: true, fee_waived: false)
    CanonicalPendingEventMapping.create!(canonical_pending_transaction_id: cpt.id, event_id: event.id)
  end
  invoice
end

def seed_cardholder(person)
  StripeCardholder.find_by(user: person) ||
    StripeCardholder.create!(user: person, stripe_id: "ich_seed_#{person.id}", cardholder_type: :individual, stripe_name: person.name, stripe_email: person.email)
end

def seed_card(event, cardholder, status:, name:, subledger: nil, last4: nil)
  card = StripeCard.new(event:, stripe_cardholder: cardholder, card_type: :virtual, subledger:,
                        stripe_id: "ic_seed_#{SecureRandom.hex(5)}", stripe_brand: "Visa", stripe_exp_month: rand(1..12),
                        stripe_exp_year: 2030, last4: last4 || rand(1000..9999).to_s, stripe_status: status,
                        initially_activated: true, name:)
  card.skip_notify_user = true
  card.save!
  card
end

def seed_card_charge(event, card, merchant, category, cents, date, uploader: nil)
  auth_id = "iauth_seed_#{SecureRandom.hex(6)}"
  rpst = RawPendingStripeTransaction.create!(stripe_transaction_id: auth_id, amount_cents: -cents, date_posted: date,
                                             stripe_transaction: { "id" => auth_id, "status" => "pending", "created" => date.to_i, "authorization_method" => "online", "amount" => cents, "pending_request" => { "amount" => cents }, "card" => { "id" => card.stripe_id }, "merchant_data" => { "name" => merchant, "network_id" => rand(10**9).to_s, "category" => category } })
  cpt = CanonicalPendingTransaction.create!(raw_pending_stripe_transaction: rpst, amount_cents: -cents, date:, memo: merchant)
  CanonicalPendingEventMapping.create!(canonical_pending_transaction_id: cpt.id, event_id: event.id, subledger_id: card.subledger_id)
  seed_receipt(cpt.local_hcb_code, uploader) if uploader
  cpt
end

def seed_card_grant(event, sender, grantee_email, cents, purpose)
  grant = CardGrant.create!(event:, sent_by: sender, email: grantee_email, amount_cents: cents, purpose:)
  card = seed_card(event, seed_cardholder(grant.user), status: "active", name: "#{purpose} card", subledger: grant.subledger)
  grant.update!(stripe_card: card)
  grant
end

def seed_payout_method(person)
  le = person.personal_legal_entity
  return if le.nil? || le.default_payout_method

  LegalEntity::PayoutMethod.create!(legal_entity: le, default: true,
                                    details: LegalEntity::PayoutMethod::AchTransfer.new(account_number: rand(10**8..10**11).to_s, routing_number: REAL_ROUTING_NUMBERS.sample))
end

def seed_reimbursement(event, person, name, expenses, state)
  seed_payout_method(person)
  report = Reimbursement::Report.create!(user: person, event:, name:)
  expenses.each do |value, memo, category|
    expense = report.expenses.create!(value:, memo:, category:)
    seed_receipt(expense, person)
  end
  return report if state == :draft

  report.mark_submitted!
  report.reload
  if report.submitted?
    report.expenses.pending.each(&:mark_approved!)
    report.mark_reimbursement_requested! unless state == :submitted
  end
  report.mark_reimbursement_approved! if state == :reimbursed && report.reimbursement_requested?
  report.mark_rejected! if state == :rejected && report.may_mark_rejected?
  report
end

# Contractor with a completed (manual) tax form, so their legal entity is payable.
def seed_contractor(event, person)
  le = person.personal_legal_entity
  Tax::Form.create!(legal_entity: le, external_service: :manual, aasm_state: :completed, entity_type: :person, sent_at: rand(5..20).days.ago, completed_at: rand(1..4).days.ago) if le.latest_completed_tax_form.nil?
  Payee.create_with(display_name: person.name).find_or_create_by!(event:, legal_entity: le, email: person.email)
end

# ---- big, reusable event populator ----------------------------------------
def populate_event!(event, admin:, organizers:, scale: 20)
  return if event.donations.exists?

  organizer = organizers.first
  seed_settled(event, "🏦 Founding grant from The Hack Foundation", 8_000_000, 35.days.ago)
  seed_settled(event, "💳 Corporate sponsorship — GitHub", 2_500_000, 28.days.ago)
  seed_settled(event, "🏦 Grant disbursement from HQ", 1_200_000, 20.days.ago)

  # --- donations: lots, with variety ---
  scale.times do |i|
    name = fake_name
    seed_donation(event, [500, 1_000, 2_500, 5_000, 10_000, 25_000, 50_000, 100_00, 250_00, 500_00].sample,
                  name:, email: fake_email("#{name}#{i}"), created_at: rand(1..34).days.ago,
                  anonymous: i.even? && i % 6 == 0, in_person: i % 7 == 0)
  end
  seed_donation(event, 100, name: fake_name, email: fake_email("min"), created_at: 9.days.ago)      # $1 minimum
  seed_donation(event, 500_00, name: fake_name, email: fake_email("max"), created_at: 6.days.ago)   # large
  3.times do |i|
    rd = RecurringDonation.new(event:, name: fake_name, email: fake_email("recurring#{i}#{event.id}"), amount: [1_000, 2_500, 5_000].sample, stripe_status: "active")
    rd.stripe_subscription_id = "sub_seed_#{SecureRandom.hex(8)}"
    rd.stripe_customer_id = "cus_seed_#{SecureRandom.hex(8)}"
    rd.save!
    seed_donation(event, rd.amount, name: nil, email: nil, created_at: rand(1..20).days.ago, recurring: rd)
  end
  # refunded & failed edge states
  refunded = Donation.create!(event:, amount: 3_000, status: "succeeded", created_at: 7.days.ago, name: fake_name, email: fake_email("refund"), url_hash: SecureRandom.hex(8), stripe_payment_intent_id: "pi_seed_#{SecureRandom.hex(8)}")
  refunded.mark_in_transit!
  refunded.mark_refunded!
  Donation.create!(event:, amount: 6_000, status: "failed", created_at: 5.days.ago, name: fake_name, email: fake_email("failed"), url_hash: SecureRandom.hex(8), stripe_payment_intent_id: "pi_seed_#{SecureRandom.hex(8)}").mark_failed!

  # --- sponsors + invoices (open / paid / manual / void) ---
  2.times do |i|
    sponsor = seed_sponsor(event, Faker::Company.name)
    %i[paid paid open manual void].each do |state|
      seed_invoice(event, sponsor, organizer, "#{Faker::Commerce.department} sponsorship (#{state})", [250_00, 500_00, 1_000_00, 2_500_00].sample, state)
    end
  end

  # --- cards + card spend (admin + organizers), many charges with receipts ---
  card_owners = ([admin] + organizers).uniq
  cards = card_owners.map do |person|
    seed_member(event, person, :manager, admin) unless person == admin
    seed_card(event, seed_cardholder(person), status: (person == organizers.last ? "inactive" : "active"), name: "#{person.name.split.first}'s card")
  end
  (scale + 10).times do |i|
    merchant, category = CARD_MERCHANTS.sample
    card = cards.sample
    seed_card_charge(event, card, merchant, category, [8_40, 12_99, 25_99, 42_00, 89_00, 120_00, 350_00, 1_200_00].sample,
                     rand(1..30).days.ago, uploader: i.even? ? card.user : nil)
  end

  # --- card grants (some to the signed-in admin so they see their own) ---
  seed_card_grant(event, admin, admin.email, 250_00, "Travel stipend")
  seed_card_grant(event, admin, admin.email, 150_00, "Food budget")
  3.times { |i| seed_card_grant(event, organizer, fake_email("grantee#{i}#{event.id}"), [50_00, 100_00, 250_00].sample, ["Hackathon travel", "Team meals", "Supplies"].sample) }

  # --- outgoing transfers ---
  3.times do |i|
    t = AchTransfer.create!(event:, creator: admin, amount: [150_00, 300_00, 750_00].sample, routing_number: REAL_ROUTING_NUMBERS.sample,
                            account_number: rand(10**8..10**11).to_s, bank_name: Faker::Bank.name, recipient_name: fake_name,
                            recipient_email: fake_email("vendor#{i}"), payment_for: ["Venue deposit", "Catering", "Equipment rental"].sample)
    t.mark_in_transit!
    t.mark_deposited! if i.even?
    t.update_column(:column_id, "acht_seed_#{SecureRandom.hex(6)}")
  end
  2.times do |i|
    IncreaseCheck.create!(event:, user: admin, amount: [100_00, 250_00, 400_00].sample, memo: "Prize payout", payment_for: "Award",
                          recipient_name: fake_name, recipient_email: fake_email("check#{i}"), address_line1: Faker::Address.street_address,
                          address_line2: "", address_city: "West Hollywood", address_state: "CA", address_zip: "90069").mark_approved!
  end
  # Wire validation performs Column bank-country lookups; skip them (still fronts a pending txn).
  Wire.new(event:, user: admin, amount_cents: 500_00, currency: "USD", memo: "International vendor", payment_for: "Merch printing",
           recipient_name: Faker::Company.name, recipient_email: fake_email("wire"), account_number: "DE89370400440532013000", bic_code: "DEUTDEFF",
           address_line1: "10 Alexanderplatz", address_line2: "", address_city: "Berlin", address_state: "BE", address_postal_code: "10178", recipient_country: "DE").save!(validate: false)
  # PayPal transfers can't be validated (model blocks new ones); create unvalidated.
  PaypalTransfer.new(event:, user: admin, amount_cents: 75_00, memo: "Speaker honorarium", payment_for: "Keynote", recipient_name: fake_name, recipient_email: fake_email("paypal")).save!(validate: false)
  WiseTransfer.create!(event:, user: admin, amount_cents: 300_00, currency: "EUR", quoted_usd_amount_cents: 330_00, usd_amount_cents: 330_00,
                       payment_for: "Contractor", recipient_name: fake_name, recipient_email: fake_email("wise"), recipient_country: "FR",
                       address_line1: "5 Rue de Rivoli", address_city: "Paris", address_state: "IDF", address_postal_code: "75001")

  # --- incoming check deposit ---
  png = "\x89PNG\r\n\x1a\n".b + SecureRandom.bytes(64)
  deposit = CheckDeposit.new(event:, created_by: admin, amount_cents: 400_00)
  deposit.front.attach(io: StringIO.new(png), filename: "front.png", content_type: "image/png")
  deposit.back.attach(io: StringIO.new(png), filename: "back.png", content_type: "image/png")
  deposit.save!

  # --- contractors: payees, payments, payroll ---
  2.times do |i|
    contractor = seed_person(fake_email("contractor#{i}#{event.id}"), fake_name)
    payee = seed_contractor(event, contractor)
    Payment.create!(payee:, creator: admin, amount_cents: [150_00, 250_00, 500_00].sample, currency: "USD", purpose: Faker::Job.title, aasm_state: "successful", sent_at: rand(1..10).days.ago, successful_at: rand(1..5).days.ago)
    next unless i.zero?

    position = Payroll::Position.create!(payee:, title: "Backend Engineer", description: "API work for the program", rate_cents: 8_500, currency: "USD", rate_unit: "hour", start_date: Date.current, end_date: 3.months.from_now, aasm_state: "onboarded")
    payroll_invoice = Payroll::Invoice.create!(payroll_position: position, amount_cents: 500_00, currency: "USD", name: "Monthly hours", aasm_state: "approved", approved_at: 1.day.ago)
    payment = Payment.create!(payee:, creator: admin, amount_cents: payroll_invoice.amount_cents, currency: "USD", purpose: payroll_invoice.name, aasm_state: "successful", sent_at: 2.hours.ago, successful_at: 1.hour.ago)
    payroll_invoice.update!(payment:)
    contract = Contract::PayrollPosition.create!(contractable: position, external_service: :manual, include_videos: false)
    contract.parties.create!(user: admin, role: :organizer)
    contract.parties.create!(external_email: payee.email, role: :contractor)
    contract.parties.update_all(aasm_state: "signed", signed_at: 1.day.ago)
    contract.update_columns(aasm_state: "signed", signed_at: 1.day.ago)
    seed_payout_method(contractor)
  end

  # --- employee (Gusto-style) payroll ---
  employee = Employee.create!(event:, entity: organizer, aasm_state: "onboarded", gusto_id: "gusto_seed_#{SecureRandom.hex(4)}")
  Employee::Payment.create!(employee:, title: "Salary — monthly", amount_cents: 3_000_00, aasm_state: "paid", reviewed_by: admin, approved_at: 1.day.ago)

  # --- reimbursements: several states, including the admin's own ---
  seed_reimbursement(event, admin, "Conference travel", [[42.50, "Taxi from airport", "Travel"], [18.75, "Team lunch", "Food & Entertainment"], [230.00, "Hotel night", "Travel"]], :reimbursed)
  seed_reimbursement(event, admin, "Workshop supplies", [[64.00, "Soldering irons", "Project Supplies"]], :reimbursement_requested)
  seed_reimbursement(event, organizer, "Swag order", [[310.00, "T-shirts", "Advertising / Marketing"]], :reimbursed)
  seed_reimbursement(event, organizer, "Unapproved gadget", [[99.00, "Drone", "Equipment & Furniture"]], :rejected)
  seed_reimbursement(event, organizers.last, "Draft expenses", [[15.00, "Stickers", "Advertising / Marketing"]], :draft)

  # --- engagement: tags on transactions, comments, announcements, documents ---
  travel_tag = Tag.create!(event:, label: "Travel", emoji: "🚌", color: "blue")
  Tag.create!(event:, label: "Food", emoji: "🍕", color: "orange")
  Tag.create!(event:, label: "Hardware", emoji: "🔧", color: "green")
  event.canonical_pending_transactions.limit(6).each_with_index do |cpt, i|
    hcb = cpt.local_hcb_code
    hcb.tags << travel_tag if i.even?
    Comment.create!(commentable: hcb, user: organizer, content: ["Please add a receipt for this.", "Reimbursed to organizer.", "Confirmed with vendor."].sample, admin_only: i.even?)
  end
  Announcement.create!(event:, author: admin, title: "Welcome to #{event.name}!",
                       content: { type: "doc", content: [{ type: "paragraph", content: [{ type: "text", text: "Our finances are now live on HCB." }] }] }, aasm_state: :published)
  Announcement.create!(event:, author: admin, title: "Draft update",
                       content: { type: "doc", content: [{ type: "paragraph", content: [{ type: "text", text: "Work in progress." }] }] }, aasm_state: :draft)
  %i[forms nonprofit_status contracts].each do |category|
    doc = Document.new(user: admin, event:, name: "#{category.to_s.titleize} document", category:)
    doc.file.attach(io: StringIO.new("Seed #{category} document."), filename: "#{category}.txt", content_type: "text/plain")
    doc.save!
  end

  event
end

# ---- shared cast of fictional people --------------------------------------
seed_payout_method(admin)
people = 12.times.map { |i| seed_person(fake_email("organizer#{i}"), fake_name) }
people.each { |p| seed_payout_method(p) }
maya, devon, priya = people[0], people[1], people[2]
auditor = seed_person("audrey.auditor@example.com", "Audrey Lin")
auditor.update!(access_level: :auditor) unless auditor.auditor?

# ===========================================================================
# Fully-populate every event the signed-in admin can see
# ===========================================================================
non_transparent_event.update!(name: "ExpensiCon 2023") # existing showcase org (non-transparent)
transparent_event.update!(name: "Hack The Seas")       # existing showcase org (transparent)

flagship = seed_org("bay-area-hacks", "Bay Area Hacks", is_public: true)
robotics = seed_org("team-8032-robotics", "Team 8032 Robotics", is_public: true)
robotics.plan.update(type: Event::Plan::FeeWaived.name) unless robotics.plan.is_a?(Event::Plan::FeeWaived)
seed_tag(flagship, EventTag::Tags::HACKATHON)
seed_tag(robotics, EventTag::Tags::ROBOTICS_TEAM)

[non_transparent_event, transparent_event, flagship, robotics].each_with_index do |event, i|
  populate_event!(event, admin:, organizers: people[(i * 3), 3], scale: 22)
end

# ===========================================================================
# Sub-organization + disbursement from the flagship parent
# ===========================================================================
suborg = seed_org("bay-area-hacks-south-bay", "Bay Area Hacks — South Bay Chapter", is_public: true, parent: flagship)
seed_member(suborg, devon, :manager, admin)
unless suborg.canonical_pending_transactions.exists?
  DisbursementService::Create.new(source_event_id: flagship.id, destination_event_id: suborg.id,
                                  name: "Seed funding for South Bay chapter", amount: "1500.00", requested_by_id: admin.id, fronted: true).run
  4.times { |i| seed_donation(suborg, [1_000, 5_000, 10_000].sample, name: fake_name, email: fake_email("sub#{i}"), created_at: rand(1..14).days.ago) }
end

# ===========================================================================
# EDGE CASE — financially frozen, high risk, mixed pending activity
# ===========================================================================
frozen_org = seed_org("frozen-assets-collective", "Frozen Assets Collective", is_public: false)
frozen_org.plan.update(type: Event::Plan::FeeWaived.name) unless frozen_org.plan.is_a?(Event::Plan::FeeWaived)
unless frozen_org.donations.exists?
  seed_settled(frozen_org, "🏦 Initial deposit", 500_000, 30.days.ago)
  5.times { |i| seed_donation(frozen_org, [2_500, 10_000].sample, name: fake_name, email: fake_email("frozen#{i}"), created_at: rand(1..20).days.ago) }
  pending = CanonicalPendingTransaction.create!(date: 2.days.ago, memo: "❄️ Suspicious purchase under review", amount_cents: -75_000)
  CanonicalPendingEventMapping.create!(canonical_pending_transaction_id: pending.id, event_id: frozen_org.id)
end
frozen_org.update!(financially_frozen: true, risk_level: :high) unless frozen_org.financially_frozen?

# ===========================================================================
# EDGE CASE — brand-new empty org (tests empty states)
# ===========================================================================
fresh = seed_org("fresh-start-hacks", "Fresh Start Hacks", is_public: true)
seed_member(fresh, maya, :manager, admin)

# ===========================================================================
# EDGE CASE — overdrawn org (negative balance)
# ===========================================================================
overdrawn = seed_org("overdrawn-outpost", "Overdrawn Outpost", is_public: false)
unless overdrawn.canonical_transactions.exists?
  seed_settled(overdrawn, "🏦 Small starting grant", 50_000, 14.days.ago)
  seed_settled(overdrawn, "💸 Emergency equipment purchase", -120_000, 3.days.ago)
end

# ===========================================================================
# ADMIN REVIEW QUEUES — pending applications & organizer-removal requests
# ===========================================================================
[["Algorithms Club", maya, "Burlington", "VT"], ["Rocketry Society", priya, "Austin", "TX"], ["Design Guild", devon, "Seattle", "WA"]].each do |name, applicant, city, state|
  Event::Application.create_with(
    description: "A student group applying for fiscal sponsorship.", address_line1: "1 Main St", address_city: city,
    address_state: state, address_postal_code: "05401", address_country: "US", aasm_state: :under_review,
    submitted_at: rand(1..5).days.ago, under_review_at: rand(1..3).days.ago, teen_led: true
  ).find_or_create_by!(user: applicant, name:)
end
priya_op = OrganizerPosition.find_by(event: transparent_event, user: priya)
OrganizerPositionDeletionRequest.create!(organizer_position: priya_op, submitted_by: priya, reason: "No longer involved with the team.") if priya_op && !OrganizerPositionDeletionRequest.exists?(organizer_position: priya_op)

# ===========================================================================
# MISC ENGAGEMENT — raffles, referral programs, event groups
# ===========================================================================
Raffle.find_or_create_by!(user: maya, program: "first-worlds-2026-macbook")
Raffle.find_or_create_by!(user: devon, program: "summer-of-making-2026")
referral_program = Referral::Program.find_or_create_by!(name: "FIRST 2026 Referrals", creator: admin)
Referral::Link.create_with(name: "Homepage banner").find_or_create_by!(program: referral_program, creator: admin)
Event::Group.find_or_create_by!(name: "My Demo Orgs", user: admin)

puts "Done!"
