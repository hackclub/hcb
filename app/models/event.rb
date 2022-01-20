# frozen_string_literal: true

class Event < ApplicationRecord
  include Hashid::Rails
  extend FriendlyId

  include PublicIdentifiable
  set_public_id_prefix :org

  has_paper_trail

  include AASM
  include PgSearch::Model
  pg_search_scope :search_name, against: [:name, :slug, :id], using: { tsearch: { prefix: true, dictionary: "english" } }

  monetize :total_fees_v2_cents

  default_scope { order(id: :asc) }
  scope :pending, -> { where(aasm_state: :pending) }
  scope :pending_or_unapproved, -> { where(aasm_state: [:pending, :unapproved]) }
  scope :transparent, -> { where(is_public: true) }
  scope :not_transparent, -> { where(is_public: false) }
  scope :omitted, -> { where(omit_stats: true) }
  scope :not_omitted, -> { where(omit_stats: false) }
  scope :hidden, -> { where("hidden_at is not null") }
  scope :v1, -> { where(transaction_engine_v2_at: nil) }
  scope :v2, -> { where.not(transaction_engine_v2_at: nil) }
  scope :not_partner, -> { where(partner_id: 1) }
  scope :partner, -> { where.not(partner_id: 1) }
  scope :hidden, -> { where.not(hidden_at: nil) }
  scope :not_hidden, -> { where(hidden_at: nil) }
  scope :funded, -> {
    includes(canonical_event_mappings: :canonical_transaction)
      .where("canonical_transactions.amount_cents > 0")
      .references(:canonical_transaction)
  }
  scope :not_funded, -> { where.not(id: funded) }
  scope :event_ids_with_pending_fees_greater_than_100, -> do
    query = <<~SQL
      ;select event_id, fee_balance from (
        select q1.event_id, COALESCE(q1.sum, 0) as total_fees, COALESCE(q2.sum, 0) as total_fee_payments, COALESCE(q1.sum, 0) + COALESCE(q2.sum, 0) as fee_balance from (

        -- step 1: calculate total_fees per event
        select fr.event_id, sum(fr.fee_amount) from fee_relationships fr
        inner join transactions t on t.fee_relationship_id = fr.id
        inner join events e on e.id = fr.event_id
        where fr.fee_applies is true and t.deleted_at is null and e.transaction_engine_v2_at is null
        group by fr.event_id

        ) q1

        left outer join (
        -- step 2: calculate total_fee_payments per event
        select fr.event_id, sum(t.amount) from fee_relationships fr
        inner join transactions t on t.fee_relationship_id = fr.id
        inner join events e on e.id = fr.event_id
        where fr.is_fee_payment is true and t.deleted_at is null and e.transaction_engine_v2_at is null
        group by fr.event_id
        ) q2

        on q1.event_id = q2.event_id
      ) q3
      where fee_balance > 100
    SQL

    ActiveRecord::Base.connection.execute(query)
  end

  scope :pending_fees, -> do
    where("(last_fee_processed_at is null or last_fee_processed_at <= ?) and id in (?)", 5.days.ago, self.event_ids_with_pending_fees_greater_than_100.to_a.map { |a| a["event_id"] })
  end

  scope :event_ids_with_pending_fees_greater_than_0_v2, -> do
    query = <<~SQL
      ;select event_id, fee_balance from (
      select
      q1.event_id,
      COALESCE(q1.sum, 0) as total_fees,
      COALESCE(q2.sum, 0) as total_fee_payments,
      COALESCE(q1.sum, 0) + COALESCE(q2.sum, 0) as fee_balance

      from (
          select
          cem.event_id,
          COALESCE(sum(f.amount_cents_as_decimal), 0) as sum
          from canonical_event_mappings cem
          inner join fees f on cem.id = f.canonical_event_mapping_id
          inner join events e on e.id = cem.event_id
          where e.transaction_engine_v2_at is not null
          group by cem.event_id
      ) as q1 left outer join (
          select
          cem.event_id,
          COALESCE(sum(ct.amount_cents), 0) as sum
          from canonical_event_mappings cem
          inner join fees f on cem.id = f.canonical_event_mapping_id
          inner join canonical_transactions ct on cem.canonical_transaction_id = ct.id
          inner join events e on e.id = cem.event_id
          where e.transaction_engine_v2_at is not null
          and f.reason = 'HACK CLUB FEE'
          group by cem.event_id
      ) q2

      on q1.event_id = q2.event_id
      ) q3
      where fee_balance > 0
      order by fee_balance desc
    SQL

    ActiveRecord::Base.connection.execute(query)
  end

  scope :pending_fees_v2, -> do
    where("(last_fee_processed_at is null or last_fee_processed_at <= ?) and id in (?)", 5.days.ago, self.event_ids_with_pending_fees_greater_than_0_v2.to_a.map { |a| a["event_id"] })
  end

  aasm do
    # All events should be approved prior to creation
    state :approved, initial: true # Full fiscal sponsorship
    state :rejected # Rejected from fiscal sponsorship

    # DEPRECATED
    state :awaiting_connect # Initial state of partner events. Waiting for user to fill out Bank Connect form
    state :pending # Awaiting Bank approval (after filling out Bank Connect form)
    state :unapproved # Old spend only events. Deprecated, should not be granted to any new events

    event :mark_pending do
      transitions from: [:awaiting_connect, :approved], to: :pending
    end

    event :mark_approved do
      transitions from: [:awaiting_connect, :pending, :unapproved], to: :approved
    end

    event :mark_rejected do
      transitions to: :rejected # from any state
    end
  end

  friendly_id :name, use: :slugged

  belongs_to :point_of_contact, class_name: "User", optional: true

  has_many :organizer_position_invites
  has_many :organizer_positions
  has_many :users, through: :organizer_positions
  has_many :g_suites
  has_many :g_suite_accounts, through: :g_suites

  has_many :fee_relationships
  has_many :transactions, through: :fee_relationships, source: :t_transaction

  has_many :stripe_cards
  has_many :stripe_authorizations, through: :stripe_cards

  has_many :emburse_cards
  has_many :emburse_card_requests
  has_many :emburse_transfers
  has_many :emburse_transactions

  has_many :ach_transfers
  has_many :disbursements
  has_many :donations
  has_many :donation_payouts, through: :donations, source: :payout

  has_many :lob_addresses
  has_many :checks, through: :lob_addresses

  has_many :sponsors
  has_many :invoices, through: :sponsors
  has_many :payouts, through: :invoices

  has_many :documents

  has_many :canonical_pending_event_mappings
  has_many :canonical_pending_transactions, through: :canonical_pending_event_mappings

  has_many :canonical_event_mappings
  has_many :canonical_transactions, through: :canonical_event_mappings

  has_many :fees, through: :canonical_event_mappings
  has_many :bank_fees

  belongs_to :partner
  has_one :partnered_signup, required: false
  has_many :partner_donations

  enum country: {
    US: 215,
    IN: 104,
    CA: 41,
    AD: 6,
    AE: 235,
    AF: 1,
    AG: 10,
    AI: 8,
    AL: 3,
    AM: 12,
    AO: 7,
    AQ: 9,
    AR: 11,
    AS: 5,
    AT: 15,
    AU: 14,
    AW: 13,
    AX: 2,
    AZ: 16,
    BA: 29,
    BB: 20,
    BD: 19,
    BE: 22,
    BF: 36,
    BG: 35,
    BH: 18,
    BI: 37,
    BJ: 24,
    BL: 186,
    BM: 25,
    BN: 34,
    BO: 27,
    BQ: 28,
    BR: 32,
    BS: 17,
    BT: 26,
    BV: 31,
    BW: 30,
    BY: 21,
    BZ: 23,
    CC: 48,
    CD: 52,
    CF: 43,
    CG: 51,
    CH: 217,
    CI: 55,
    CK: 53,
    CL: 45,
    CM: 40,
    CN: 46,
    CO: 49,
    CR: 54,
    CU: 57,
    CV: 38,
    CW: 58,
    CX: 47,
    CY: 59,
    CZ: 60,
    DE: 84,
    DJ: 62,
    DK: 61,
    DM: 63,
    DO: 64,
    DZ: 4,
    EC: 65,
    EE: 70,
    EG: 66,
    EH: 246,
    ER: 69,
    ES: 210,
    ET: 72,
    FI: 76,
    FJ: 75,
    FK: 73,
    FM: 145,
    FO: 74,
    FR: 77,
    GA: 81,
    GB: 236,
    GD: 89,
    GE: 83,
    GF: 78,
    GG: 93,
    GH: 85,
    GI: 86,
    GL: 88,
    GM: 82,
    GN: 94,
    GP: 90,
    GQ: 68,
    GR: 87,
    GS: 208,
    GT: 92,
    GU: 91,
    GW: 95,
    GY: 96,
    HK: 101,
    HM: 98,
    HN: 100,
    HR: 56,
    HT: 97,
    HU: 102,
    ID: 105,
    IE: 108,
    IL: 110,
    IM: 109,
    IO: 33,
    IQ: 107,
    IR: 106,
    IS: 103,
    IT: 111,
    JE: 114,
    JM: 112,
    JO: 115,
    JP: 113,
    KE: 117,
    KG: 122,
    KH: 39,
    KI: 118,
    KM: 50,
    KN: 188,
    KP: 119,
    KR: 120,
    KW: 121,
    KY: 42,
    KZ: 116,
    LA: 123,
    LB: 125,
    LC: 189,
    LI: 129,
    LK: 211,
    LR: 127,
    LS: 126,
    LT: 130,
    LU: 131,
    LV: 124,
    LY: 128,
    MA: 151,
    MC: 147,
    MD: 146,
    ME: 149,
    MF: 190,
    MG: 133,
    MH: 139,
    MK: 165,
    ML: 137,
    MM: 153,
    MN: 148,
    MO: 132,
    MP: 166,
    MQ: 140,
    MR: 141,
    MS: 150,
    MT: 138,
    MU: 142,
    MV: 136,
    MW: 134,
    MX: 144,
    MY: 135,
    MZ: 152,
    NA: 154,
    NC: 158,
    NE: 161,
    NF: 164,
    NG: 162,
    NI: 160,
    NL: 157,
    NO: 167,
    NP: 156,
    NR: 155,
    NU: 163,
    NZ: 159,
    OM: 168,
    PA: 172,
    PE: 175,
    PF: 79,
    PG: 173,
    PH: 176,
    PK: 169,
    PL: 178,
    PM: 191,
    PN: 177,
    PR: 180,
    PS: 171,
    PT: 179,
    PW: 170,
    PY: 174,
    QA: 181,
    RE: 182,
    RO: 183,
    RS: 198,
    RU: 184,
    RW: 185,
    SA: 196,
    SB: 205,
    SC: 199,
    SD: 212,
    SE: 216,
    SG: 201,
    SH: 187,
    SI: 204,
    SJ: 214,
    SK: 203,
    SL: 200,
    SM: 194,
    SN: 197,
    SO: 206,
    SR: 213,
    SS: 209,
    ST: 195,
    SV: 67,
    SX: 202,
    SY: 218,
    SZ: 71,
    TC: 231,
    TD: 44,
    TF: 80,
    TG: 224,
    TH: 222,
    TJ: 220,
    TK: 225,
    TL: 223,
    TM: 230,
    TO: 226,
    TR: 229,
    TT: 227,
    TV: 232,
    TW: 219,
    TZ: 221,
    UA: 234,
    UG: 233,
    UM: 237,
    UY: 238,
    UZ: 239,
    VA: 99,
    VC: 192,
    VE: 241,
    VG: 243,
    VI: 244,
    VN: 242,
    VU: 240,
    WF: 245,
    WS: 193,
    YE: 247,
    YT: 143,
    ZA: 207,
    ZM: 248,
    ZW: 249,
  }

  validate :point_of_contact_is_admin

  validates :name, :sponsorship_fee, presence: true
  validates :slug, uniqueness: true, presence: true, format: { without: /\s/ }

  CUSTOM_SORT = "CASE WHEN id = 183 THEN '1'
                      WHEN id = 999 THEN '2'
                      WHEN id = 689 THEN '3'
                      WHEN id = 636 THEN '4'
                      ELSE 'z' || name END ASC"

  def country_us?
    country == "US"
  end

  def admin_formatted_name
    "#{name} (#{id})"
  end

  # When a fee payment is collected from this event, what will the TX memo be?
  def fee_payment_memo
    "#{self.name} Bank Fee"
  end

  def admin_dropdown_description
    "#{name} - #{id}"
  end

  def eligible_for_free_domain?
    # We're only launching this feature in the US for the first week while we
    # iron out the kinks
    passes_country_check = (country == "US" || Date.today > Date.new(2021, 11, 17))
    does_not_have_gsuite = g_suites.not_deleted.none?

    does_not_have_gsuite and passes_country_check
  end

  # displayed on /negative_events
  def self.negatives
    select { |event| event.balance < 0 || event.emburse_balance < 0 || event.fee_balance < 0 }
  end

  def emburse_department_path
    "https://app.emburse.com/budgets/#{emburse_department_id}"
  end

  def emburse_budget_limit
    # We want to count positive Emburse TXs that are either pending OR complete,
    # because pending TXs will silently switch to complete and the admin will not
    # be notified to update the Emburse budget for this event later when that happens.
    # See also PR #317.
    self.emburse_transactions.undeclined.where(emburse_card_uuid: nil).sum(:amount)
  end

  def emburse_balance
    completed_t = self.emburse_transactions.completed.sum(:amount)
    # We're including only pending charges on emburse_cards so organizers have a conservative estimate of their balance
    pending_t = self.emburse_transactions.pending.where("amount < 0").sum(:amount)
    completed_t + pending_t
  end

  def balance_v2_cents
    @balance_v2_cents ||= canonical_transactions.sum(:amount_cents) + pending_outgoing_balance_v2_cents
  end

  def pending_balance_v2_cents
    @pending_balance_v2_cents ||= pending_incoming_balance_v2_cents + pending_outgoing_balance_v2_cents
  end

  def pending_incoming_balance_v2_cents
    @pending_incoming_balance_v2_cents ||= canonical_pending_transactions.incoming.unsettled.sum(:amount_cents)
  end

  def pending_outgoing_balance_v2_cents
    @pending_outgoing_balance_v2_cents ||= canonical_pending_transactions.outgoing.unsettled.sum(:amount_cents)
  end

  def balance_available_v2_cents
    @balance_available_v2_cents ||= balance_v2_cents - fee_balance_v2_cents
  end

  def balance
    return balance_v2_cents if transaction_engine_v2_at.present?

    bank_balance = transactions.sum(:amount)
    stripe_balance = -stripe_authorizations.approved.sum(:amount)

    bank_balance + stripe_balance
  end

  # used for emburse transfers, this is the amount of money available that
  # isn't being transferred out by an emburse_transfer or isn't going to be
  # pulled out via fee -tmb@hackclub
  def balance_available
    return balance_available_v2_cents if transaction_engine_v2_at.present?

    emburse_transfer_pending = (emburse_transfers.under_review + emburse_transfers.pending).sum(&:load_amount)
    balance - emburse_transfer_pending - fee_balance
  end
  alias available_balance balance_available

  def fee_balance
    return fee_balance_v2_cents if transaction_engine_v2_at.present?

    @fee_balance ||= total_fees - total_fee_payments
  end

  def fee_balance_v2_cents
    @fee_balance_v2_cents ||= total_fees_v2_cents - total_fee_payments_v2_cents
  end

  # amount of balance that fees haven't been pulled out for
  def balance_not_feed
    a_fee_balance = self.fee_balance

    self.transactions.where.not(fee_reimbursement: nil).each do |t|
      a_fee_balance -= (100 - t.fee_reimbursement.amount) if t.fee_reimbursement.amount < 100
    end

    percent = self.sponsorship_fee * 100

    (a_fee_balance * 100 / percent)
  end

  def balance_not_feed_v2_cents
    # shortcut to invert - TODO: DEPRECATE. dangerous - causes incorrect calculations
    BigDecimal(fee_balance_v2_cents.to_s) / BigDecimal(sponsorship_fee.to_s)
  end

  def fee_balance_without_fee_reimbursement_reconcilliation
    a_fee_balance = self.fee_balance
    self.transactions.where.not(fee_reimbursement: nil).each do |t|
      a_fee_balance -= (100 - t.fee_reimbursement.amount) if t.fee_reimbursement.amount < 100
    end

    a_fee_balance
  end

  def plan_name
    if unapproved?
      "pending approval"
    else
      "full fiscal sponsorship"
    end
  end

  def has_active_emburse?
    emburse_cards.active.any?
  end

  def used_emburse?
    emburse_cards.any?
  end

  def hidden?
    hidden_at.present?
  end

  def filter_data
    {
      exists: true,
      transparent: is_public?,
      omitted: omit_stats?,
      hidden: hidden?
    }
  end

  def ready_for_fee?
    last_fee_processed_at.nil? || last_fee_processed_at <= min_waiting_time_between_fees
  end

  def total_fees_v2_cents
    @total_fess_v2_cents ||= fees.sum(:amount_cents_as_decimal).ceil
  end

  private

  def min_waiting_time_between_fees
    5.days.ago
  end

  def point_of_contact_is_admin
    return unless point_of_contact # for remote partner created events
    return if point_of_contact&.admin?

    errors.add(:point_of_contact, "must be an admin")
  end

  def total_fees
    @total_fees ||= transactions.joins(:fee_relationship).where(fee_relationships: { fee_applies: true }).sum("fee_relationships.fee_amount")
  end

  # fee payments are withdrawals, so negate value
  def total_fee_payments
    @total_fee_payments ||= -transactions.joins(:fee_relationship).where(fee_relationships: { is_fee_payment: true }).sum(:amount)
  end

  def total_fee_payments_v2_cents
    @total_fee_payments_v2_cents ||= -canonical_transactions.where(id: canonical_transaction_ids_from_hack_club_fees).sum(:amount_cents)
  end

  def canonical_event_mapping_ids_from_hack_club_fees
    @canonical_event_mapping_ids_from_hack_club_fees ||= fees.hack_club_fee.pluck(:canonical_event_mapping_id)
  end

  def canonical_transaction_ids_from_hack_club_fees
    @canonical_transaction_ids_from_hack_club_fees ||= CanonicalEventMapping.find(canonical_event_mapping_ids_from_hack_club_fees).pluck(:canonical_transaction_id)
  end

end
