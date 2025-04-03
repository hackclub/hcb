# frozen_string_literal: true

# == Schema Information
#
# Table name: events
#
#  id                                           :bigint           not null, primary key
#  aasm_state                                   :string
#  activated_at                                 :datetime
#  address                                      :text
#  can_front_balance                            :boolean          default(TRUE), not null
#  country                                      :integer
#  deleted_at                                   :datetime
#  demo_mode                                    :boolean          default(FALSE), not null
#  demo_mode_request_meeting_at                 :datetime
#  description                                  :text
#  donation_page_enabled                        :boolean          default(TRUE)
#  donation_page_message                        :text
#  donation_reply_to_email                      :text
#  donation_thank_you_message                   :text
#  hidden_at                                    :datetime
#  holiday_features                             :boolean          default(TRUE), not null
#  is_indexable                                 :boolean          default(TRUE)
#  is_public                                    :boolean          default(TRUE)
#  last_fee_processed_at                        :datetime
#  name                                         :text
#  postal_code                                  :string
#  public_message                               :text
#  public_reimbursement_page_enabled            :boolean          default(FALSE), not null
#  public_reimbursement_page_message            :text
#  reimbursements_require_organizer_peer_review :boolean          default(FALSE), not null
#  risk_level                                   :integer
#  short_name                                   :string
#  slug                                         :text
#  stripe_card_shipping_type                    :integer          default("standard"), not null
#  website                                      :string
#  created_at                                   :datetime         not null
#  updated_at                                   :datetime         not null
#  emburse_department_id                        :string
#  increase_account_id                          :string           not null
#  point_of_contact_id                          :bigint
#
# Indexes
#
#  index_events_on_point_of_contact_id  (point_of_contact_id)
#
# Foreign Keys
#
#  fk_rails_...  (point_of_contact_id => users.id)
#
class Event < ApplicationRecord
  MIN_WAITING_TIME_BETWEEN_FEES = 5.days

  include Hashid::Rails
  extend FriendlyId

  include PublicIdentifiable
  set_public_id_prefix :org

  include CountryEnumable
  has_country_enum

  include Commentable

  has_paper_trail
  acts_as_paranoid
  validates_as_paranoid

  validates_email_format_of :donation_reply_to_email, allow_nil: true, allow_blank: true
  normalizes :donation_reply_to_email, with: ->(donation_reply_to_email) { donation_reply_to_email.strip.downcase }
  validates :donation_thank_you_message, length: { maximum: 500 }
  MAX_SHORT_NAME_LENGTH = 16
  validates :short_name, length: { maximum: MAX_SHORT_NAME_LENGTH }, allow_blank: true

  include AASM
  include PgSearch::Model
  pg_search_scope :search_name, against: [:name, :slug, :id], using: { tsearch: { prefix: true, dictionary: "simple" } }

  monetize :total_fees_v2_cents

  default_scope { order(id: :asc) }

  scope :active, -> {
    includes(canonical_event_mappings: :canonical_transaction)
      .where("canonical_transactions.created_at > ?", 1.year.ago)
      .references(:canonical_transaction)
  }

  scope :inactive, -> { where.not(id: Event.active.pluck(:id)) }

  scope :pending, -> { where(aasm_state: :pending) }
  scope :transparent, -> { where(is_public: true) }
  scope :not_transparent, -> { where(is_public: false) }
  scope :indexable, -> { where(is_public: true, is_indexable: true, demo_mode: false) }
  scope :omitted, -> { includes(:plan).where(plan: { type: Event::Plan.that(:omit_stats).collect(&:name) }) }
  scope :not_omitted, -> { includes(:plan).where.not(plan: { type: Event::Plan.that(:omit_stats).collect(&:name) }) }
  scope :hidden, -> { where("hidden_at is not null") }
  scope :hidden, -> { where.not(hidden_at: nil) }
  scope :not_hidden, -> { where(hidden_at: nil) }
  scope :funded, -> {
    includes(canonical_event_mappings: :canonical_transaction)
      .where("canonical_transactions.amount_cents > 0")
      .references(:canonical_transaction)
  }
  scope :not_funded, -> { where.not(id: funded) }
  scope :organized_by_hack_clubbers, -> { includes(:event_tags).where(event_tags: { name: EventTag::Tags::ORGANIZED_BY_HACK_CLUBBERS }) }
  scope :not_organized_by_hack_clubbers, -> { includes(:event_tags).where.not(event_tags: { name: EventTag::Tags::ORGANIZED_BY_HACK_CLUBBERS }).or(includes(:event_tags).where(event_tags: { name: nil })) }
  scope :organized_by_teenagers, -> { includes(:event_tags).where(event_tags: { name: [EventTag::Tags::ORGANIZED_BY_TEENAGERS, EventTag::Tags::ORGANIZED_BY_HACK_CLUBBERS] }) }
  scope :not_organized_by_teenagers, -> { includes(:event_tags).where.not(event_tags: { name: [EventTag::Tags::ORGANIZED_BY_TEENAGERS, EventTag::Tags::ORGANIZED_BY_HACK_CLUBBERS] }).or(includes(:event_tags).where(event_tags: { name: nil })) }
  scope :robotics_team, -> { includes(:event_tags).where(event_tags: { name: EventTag::Tags::ROBOTICS_TEAM }) }
  scope :flag_enabled, ->(flag) {
    joins("INNER JOIN flipper_gates ON CONCAT('Event;', events.id) = flipper_gates.value")
      .where("flipper_gates.feature_key = ? AND flipper_gates.key = ?", flag, "actors")
  }

  scope :event_ids_with_pending_fees, -> do
    query = <<~SQL
      ;select event_id, fee_balance from (
      select
      q1.event_id,
      COALESCE(q1.sum, 0) as total_fees,
      COALESCE(q2.sum, 0) as total_fee_payments,
      CEIL(COALESCE(q1.sum, 0)) + CEIL(COALESCE(q2.sum, 0)) as fee_balance

      from (
          select
          cem.event_id,
          COALESCE(sum(f.amount_cents_as_decimal), 0) as sum
          from canonical_event_mappings cem
          inner join fees f on cem.id = f.canonical_event_mapping_id
          inner join events e on e.id = cem.event_id
          group by cem.event_id
      ) as q1 left outer join (
          select
          cem.event_id,
          COALESCE(sum(ct.amount_cents), 0) as sum
          from canonical_event_mappings cem
          inner join fees f on cem.id = f.canonical_event_mapping_id
          inner join canonical_transactions ct on cem.canonical_transaction_id = ct.id
          inner join events e on e.id = cem.event_id
          and f.reason = 'HACK CLUB FEE'
          group by cem.event_id
      ) q2

      on q1.event_id = q2.event_id
      ) q3
      where fee_balance != 0
      order by fee_balance desc
    SQL

    ActiveRecord::Base.connection.execute(query)
  end

  scope :pending_fees_v2, -> do
    where("(last_fee_processed_at is null or last_fee_processed_at <= ?) and id in (?)", MIN_WAITING_TIME_BETWEEN_FEES.ago, self.event_ids_with_pending_fees.to_a.map { |a| a["event_id"] })
  end

  scope :demo_mode, -> { where(demo_mode: true) }
  scope :not_demo_mode, -> { where(demo_mode: false) }
  scope :filter_demo_mode, ->(demo_mode) { demo_mode.nil? ? all : where(demo_mode:) }

  before_validation :enforce_transparency_eligibility

  BADGES = {
    # Qualifier must be a method on Event. If the method returns true, the badge
    # will be displayed for the event.
    omit_stats: {
      qualifier: :omit_stats?,
      emoji: "🏦",
      description: "Omitted from stats"
    },
    transparent: {
      qualifier: :is_public?,
      emoji: "📈",
      description: "Transparency mode enabled"
    },
    hidden: {
      qualifier: :hidden_at?,
      emoji: "🕵️‍♂️",
      description: "Hidden"
    },
    organized_by_hack_clubbers: {
      qualifier: :organized_by_hack_clubbers?,
      emoji: "🦕",
      description: "Organized by Hack Clubbers"
    },
    demo_mode: {
      qualifier: :demo_mode?,
      emoji: "🧪",
      description: "Demo Account"
    }
  }.freeze

  aasm do
    # All events should be approved prior to creation
    state :approved, initial: true # Full fiscal sponsorship
    state :rejected # Rejected from fiscal sponsorship

    # DEPRECATED
    state :unapproved # Old spend only events. Deprecated, should not be granted to any new events
    state :pending

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

  # we keep a papertrail of historic plans
  has_many :plans, class_name: "Event::Plan", inverse_of: :event
  has_one :plan, -> { where(aasm_state: :active) }, class_name: "Event::Plan", inverse_of: :event, required: true

  has_one :config, class_name: "Event::Configuration"
  accepts_nested_attributes_for :config

  # Used for tracking slug history
  has_many :slugs, -> { order(id: :desc) }, class_name: "FriendlyId::Slug", as: :sluggable, dependent: :destroy

  has_many :organizer_position_invites, dependent: :destroy
  has_many :organizer_positions, dependent: :destroy
  has_many :organizer_position_contracts, through: :organizer_position_invites, class_name: "OrganizerPosition::Contract"
  has_many :users, through: :organizer_positions
  has_many :signees, -> { where(organizer_positions: { is_signee: true }) }, through: :organizer_positions, source: :user
  has_many :g_suites
  has_many :g_suite_accounts, through: :g_suites

  has_many :fee_relationships
  has_many :transactions, through: :fee_relationships, source: :t_transaction

  has_many :stripe_cards
  has_many :stripe_authorizations, through: :stripe_cards
  has_many :stripe_card_personalization_designs, class_name: "StripeCard::PersonalizationDesign", inverse_of: :event

  has_many :emburse_cards
  has_many :emburse_card_requests
  has_many :emburse_transfers
  has_many :emburse_transactions

  has_many :ach_transfers
  has_many :payment_recipients
  has_many :disbursements
  has_many :incoming_disbursements, class_name: "Disbursement"
  has_many :outgoing_disbursements, class_name: "Disbursement", foreign_key: :source_event_id
  has_many :donations
  has_many :donation_payouts, through: :donations, source: :payout
  has_many :recurring_donations
  has_one :donation_goal, dependent: :destroy, class_name: "Donation::Goal"

  has_many :lob_addresses
  has_many :checks, through: :lob_addresses
  has_many :increase_checks

  has_many :paypal_transfers

  has_many :wires

  has_many :sponsors
  has_many :invoices, through: :sponsors
  has_many :payouts, through: :invoices

  has_many :reimbursement_reports, class_name: "Reimbursement::Report"

  has_many :employees
  has_many :employee_payments, through: :employees, source: :payments, class_name: "Employee::Payment"

  has_many :documents

  has_many :canonical_pending_event_mappings, -> { on_main_ledger }
  has_many :canonical_pending_transactions, through: :canonical_pending_event_mappings

  has_many :canonical_event_mappings, -> { on_main_ledger }
  has_many :canonical_transactions, through: :canonical_event_mappings

  scope :engaged, -> {
    Event.where(id: Event.joins(:canonical_transactions)
        .where("canonical_transactions.date >= ?", 6.months.ago)
        .distinct)
  }

  scope :dormant, -> { where.not(id: Event.engaged) }

  has_many :fees
  has_many :bank_fees

  has_many :tags, -> { includes(:hcb_codes) }
  has_and_belongs_to_many :event_tags

  has_many :pinned_hcb_codes, -> { includes(hcb_code: [:canonical_transactions, :canonical_pending_transactions]) }, class_name: "HcbCode::Pin"

  has_many :check_deposits

  has_many :subledgers

  has_many :card_grants
  has_one :card_grant_setting
  accepts_nested_attributes_for :card_grant_setting, update_only: true

  has_one :increase_account_number

  has_one :column_account_number, class_name: "Column::AccountNumber"
  delegate :account_number, :routing_number, :bic_code, to: :column_account_number, allow_nil: true

  has_many :grants

  has_one_attached :donation_header_image
  validates :donation_header_image, content_type: [:png, :jpeg]

  has_one_attached :background_image
  validates :background_image, content_type: [:png, :jpeg]

  has_one_attached :logo
  validates :logo, content_type: [:png, :jpeg]

  has_one_attached :stripe_card_logo
  validates :stripe_card_logo, content_type: [:png, :jpeg]

  include HasMetrics

  include HasTasks

  validate :point_of_contact_is_admin

  include ::UserService::CanOpenDemoMode
  attr_accessor :demo_mode_limit_email

  validate :demo_mode_limit, if: proc{ |e| e.demo_mode_limit_email }
  validate :contract_signed, unless: :demo_mode?

  validates :name, presence: true
  before_validation { self.name = name.gsub(/\s/, " ").strip unless name.nil? }

  validates :slug, presence: true, format: { without: /\s/ }
  validates :slug, format: { without: /\A\d+\z/ }
  validates_uniqueness_of_without_deleted :slug

  after_save :update_slug_history

  validates :website, format: URI::DEFAULT_PARSER.make_regexp(%w[http https]), if: -> { website.present? }

  validates :postal_code, zipcode: { country_code_attribute: :country, message: "is not valid" }, allow_blank: true

  before_create { self.increase_account_id ||= "account_phqksuhybmwhepzeyjcb" }

  before_update if: -> { demo_mode_changed?(to: false) } do
    self.activated_at = Time.now
  end

  before_validation do
    build_plan(type: Event::Plan::Standard) if plan.nil?
  end

  # Explanation: https://github.com/norman/friendly_id/blob/0500b488c5f0066951c92726ee8c3dcef9f98813/lib/friendly_id/reserved.rb#L13-L28
  after_validation :move_friendly_id_error_to_slug

  after_update :generate_stripe_card_designs, if: -> { attachment_changes["stripe_card_logo"].present? && stripe_card_logo.attached? && !Rails.env.test? }

  comma do
    id
    name
    revenue_fee
    slug "url" do |slug| "https://hcb.hackclub.com/#{slug}" end
    country
    is_public "transparent"
  end

  CUSTOM_SORT = Arel.sql(
    "CASE WHEN id = 183 THEN '1'"\
    "WHEN id = 999 THEN '2'     "\
    "WHEN id = 689 THEN '3'     "\
    "WHEN id = 636 THEN '4'     "\
    "WHEN id = 506 THEN '5'     "\
    "WHEN id = 4318 THEN '6'    "\
    "ELSE 'z' || name END ASC   "
  )

  enum :stripe_card_shipping_type, {
    standard: 0,
    express: 1,
    priority: 2,
  }

  enum :risk_level, {
    zero: 0,
    slight: 1,
    moderate: 2,
    high: 3,
  }, suffix: :risk_level

  include PublicActivity::Model
  tracked owner: proc{ |controller, record| controller&.current_user }, event_id: proc { |controller, record| record.id }, only: [:create]

  def admin_formatted_name
    "#{name} (#{id})"
  end

  def admin_dropdown_description
    "#{name} - #{id}#{" (DEMO)" if demo_mode?}"

    # Causing n+1 queries on admin pages with an event dropdown

    # badges = BADGES.map { |_, badge| send(badge[:qualifier]) ? badge[:emoji] : nil }.compact
    # desc += " [#{badges.join(' ')}]" if badges.any?

    # desc
  end

  def disbursement_dropdown_description
    "#{name} (#{ApplicationController.helpers.render_money balance_available})"
  end

  # displayed on /negative_events
  def self.negatives
    select { |event| event.balance_v2_cents < 0 }
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

  def total_raised
    balance = settled_incoming_balance_cents
    if can_front_balance?
      balance += fronted_incoming_balance_v2_cents
    end
    balance
  end

  def balance_v2_cents(start_date: nil, end_date: nil)
    sum = settled_balance_cents(start_date:, end_date:)
    sum += pending_outgoing_balance_v2_cents(start_date:, end_date:)
    sum += fronted_incoming_balance_v2_cents(start_date:, end_date:) if can_front_balance?
    sum
  end

  # This calculates v2 cents of settled (Canonical Transactions)
  # @return [Integer] Balance in cents (v2 transaction engine)
  def settled_balance_cents(start_date: nil, end_date: nil)
    settled_incoming_balance_cents(start_date:, end_date:) + settled_outgoing_balance_cents(start_date:, end_date:)
  end

  # v2 cents (v2 transaction engine)
  def settled_incoming_balance_cents(start_date: nil, end_date: nil)
    ct = canonical_transactions.where("amount_cents > 0")

    ct = ct.where("date >= ?", start_date) if start_date
    ct = ct.where("date <= ?", end_date) if end_date

    ct.sum(:amount_cents)
  end

  # v2 cents (v2 transaction engine)
  def settled_outgoing_balance_cents(start_date: nil, end_date: nil)
    ct = canonical_transactions.where("amount_cents < 0")

    ct = ct.where("date >= ?", start_date) if start_date
    ct = ct.where("date <= ?", end_date) if end_date

    ct.sum(:amount_cents)
  end

  def fronted_incoming_balance_v2_cents(start_date: nil, end_date: nil)
    pts = canonical_pending_transactions.incoming.fronted.not_declined

    pts = pts.where("date >= ?", @start_date) if @start_date
    pts = pts.where("date <= ?", @end_date) if @end_date

    sum_fronted_amount(pts)
  end

  def pending_balance_v2_cents(start_date: nil, end_date: nil)
    pending_incoming_balance_v2_cents(start_date:, end_date:) + pending_outgoing_balance_v2_cents(start_date:, end_date:)
  end

  def pending_incoming_balance_v2_cents(start_date: nil, end_date: nil)
    cpt = canonical_pending_transactions.incoming.unsettled.not_fronted

    cpt = cpt.where("date >= ?", start_date) if start_date
    cpt = cpt.where("date <= ?", end_date) if end_date

    cpt.sum(:amount_cents)
  end

  def pending_outgoing_balance_v2_cents(start_date: nil, end_date: nil)
    cpt = canonical_pending_transactions.outgoing.unsettled

    cpt = cpt.where("date >= ?", start_date) if start_date
    cpt = cpt.where("date <= ?", end_date) if end_date

    cpt.sum(:amount_cents)
  end

  def balance_available_v2_cents
    @balance_available_v2_cents ||= begin
      fee_balance = can_front_balance? ? fronted_fee_balance_v2_cents : fee_balance_v2_cents
      if fee_balance.positive?
        balance_v2_cents - fee_balance
      else # `fee_balance` is negative, indicating a fee credit
        balance_v2_cents
      end
    end
  end

  alias balance balance_v2_cents

  # used for events with a pending ledger, this is the amount of money available
  # that isn't being transferred out by upcoming/floating transactions such as
  # pending fees or checks awaiting deposit -tmb@hackclub
  alias balance_available balance_available_v2_cents
  alias available_balance balance_available


  # `fee_balance_v2_cents`, but it includes fees on fronted (unsettled) transactions to prevent overspending before fees are charged
  def fronted_fee_balance_v2_cents
    feed_fronted_pts = canonical_pending_transactions
                       .incoming
                       .fronted
                       .not_waived
                       .not_declined

    feed_fronted_balance = sum_fronted_amount(feed_fronted_pts)

    (fees.sum(:amount_cents_as_decimal) - total_fee_payments_v2_cents + (feed_fronted_balance * revenue_fee)).ceil
  end

  # This intentionally does not include fees on fronted transactions to make sure they aren't actually charged
  def fee_balance_v2_cents
    @fee_balance_v2_cents ||= total_fees_v2_cents - total_fee_payments_v2_cents
  end

  alias fee_balance fee_balance_v2_cents

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
    last_fee_processed_at.nil? || last_fee_processed_at <= MIN_WAITING_TIME_BETWEEN_FEES.ago
  end

  def total_fees_v2_cents
    @total_fees_v2_cents ||= fees.sum(:amount_cents_as_decimal).ceil
  end

  def increase_account_number_id
    (increase_account_number || create_increase_account_number).increase_account_number_id
  end

  def organized_by_hack_clubbers?
    event_tags.where(name: EventTag::Tags::ORGANIZED_BY_HACK_CLUBBERS).exists?
  end

  def organized_by_teenagers?
    event_tags.where(name: [EventTag::Tags::ORGANIZED_BY_TEENAGERS, EventTag::Tags::ORGANIZED_BY_HACK_CLUBBERS]).exists?
  end

  def robotics_team?
    event_tags.where(name: EventTag::Tags::ROBOTICS_TEAM).exists?
  end

  def hackathon?
    event_tags.where(name: EventTag::Tags::HACKATHON).exists?
  end

  def reload
    @total_fee_payments_v2_cents = nil
    super
  end

  def total_fee_payments_v2_cents
    @total_fee_payments_v2_cents ||=
      begin
        paid = canonical_transactions.includes(:fee).where(fee: { reason: "HACK CLUB FEE" }).sum(:amount_cents)
        in_transit = canonical_pending_transactions.bank_fee.unsettled.sum(:amount_cents)

        (paid + in_transit) * -1
      end
  end

  def color
    options = [
      "#ec3750",
      "#ff8c37",
      "#f1c40f",
      "#33d6a6",
      "#5bc0de",
      "#338eda",
      "#a633d6",
    ]

    options[hashid.codepoints.first % options.size]
  end

  def service_level
    return 1 if robotics_team?
    return 1 if organized_by_hack_clubbers?
    return 1 if organized_by_teenagers?
    return 1 if plan.is_a?(Event::Plan::HackClubAffiliate)
    return 1 if canonical_transactions.revenue.where("date >= ?", 1.year.ago).sum(:amount_cents) >= 50_000_00
    return 1 if balance_available_v2_cents > 50_000_00

    2
  end

  def engaged?
    canonical_transactions.where("date >= ?", 6.months.ago).any?
  end

  def dormant?
    !engaged?
  end

  def revenue_fee
    plan&.revenue_fee || (Airbrake.notify("#{id} is missing a plan!") && 0.07)
  end

  def generate_stripe_card_designs
    raise ArgumentError.new("This method requires a stripe_card_logo to be attached.") unless stripe_card_logo.attached?

    ActiveRecord::Base.transaction do
      stripe_card_personalization_designs.update(stale: true)
      stripe_card_logo.blob.open do |tempfile|
        converted = ImageProcessing::MiniMagick.source(tempfile.path).convert!("png")
        ::StripeCardService::PersonalizationDesign::Create.new(file: StringIO.new(converted.read), color: :black, event: self).run
        converted.rewind
        ::StripeCardService::PersonalizationDesign::Create.new(file: StringIO.new(converted.read), color: :white, event: self).run
      end
    end
  rescue Stripe::InvalidRequestError => e
    stripe_card_logo.delete
    raise Errors::InvalidStripeCardLogoError, e.message
  end

  def airtable_record
    ApplicationsTable.all(filter: "{HCB ID} = '#{id}'").first
  end

  def default_stripe_card_personalization_design
    stripe_card_personalization_designs.where("stripe_name like ?", "#{name} Black Card%").order(created_at: :desc).first
  end

  def config
    super || create_config
  end

  def donation_page_available?
    donation_page_enabled && plan.donations_enabled?
  end

  def public_reimbursement_page_available?
    public_reimbursement_page_enabled && plan.reimbursements_enabled?
  end

  def short_name(length: MAX_SHORT_NAME_LENGTH)
    return name if length >= name.length

    self[:short_name] || name[0...length]
  end

  monetize :minimum_wire_amount_cents

  def minimum_wire_amount_cents
    return 100 if canonical_transactions.where("amount_cents > 0").where("date >= ?", 1.year.ago).sum(:amount_cents) > 50_000_00
    return 100 if plan.exempt_from_wire_minimum?
    return 100 if Flipper.enabled?(:exempt_from_wire_minimum, self)

    return 500_00
  end

  def omit_stats?
    plan.omit_stats
  end

  def eligible_for_transparency?
    !plan.is_a?(Event::Plan::SalaryAccount)
  end

  def eligible_for_indexing?
    eligible_for_transparency? && !risk_level.in?(%w[moderate high])
  end

  def sync_to_airtable
    # Sync stats to application's airtable record
    ApplicationsTable.all(filter: "{HCB ID} = \"#{self.id}\"").each do |app| # rubocop:disable Rails/FindEach
      app["Active Teens (last 30 days)"] = users.where(teenager: true).last_seen_within(30.days.ago).size

      # For Anish's TUB
      app["Referral New Signee Under 18"] = organizer_positions.includes(:user).where(is_signee: true, user: { teenager: true }).any?
      app["Referral Raised 25"] = total_raised > 25_00
      app["Referral Transparent"] = is_public
      app["Referral 2 Teen Members"] = organizer_positions.includes(:user).where(user: { teenager: true }).count > 2

      app.save
    end
  end

  private

  def point_of_contact_is_admin
    return unless point_of_contact_changed?
    return unless point_of_contact
    return if point_of_contact&.admin_override_pretend?

    errors.add(:point_of_contact, "must be an admin")
  end

  def update_slug_history
    if slug_previously_changed?
      slugs.create(slug:)
    end
  end

  def demo_mode_limit
    return if can_open_demo_mode? demo_mode_limit_email

    errors.add(:demo_mode, "limit reached for user")
  end

  def contract_signed
    return if organizer_position_contracts.signed.any? || organizer_position_contracts.none?

    errors.add(:base, "Missing a contract signee, non-demo mode organizations must have a contract signee.")
  end

  def sum_fronted_amount(pts)
    pt_sum_by_hcb_code = pts.group(:hcb_code).sum(:amount_cents)
    hcb_codes = pt_sum_by_hcb_code.keys

    ct_sum_by_hcb_code = canonical_transactions.where(hcb_code: hcb_codes)
                                               .group(:hcb_code)
                                               .sum(:amount_cents)

    pt_sum_by_hcb_code.reduce 0 do |sum, (hcb_code, pt_sum)|
      sum + [pt_sum - (ct_sum_by_hcb_code[hcb_code] || 0), 0].max
    end
  end

  def move_friendly_id_error_to_slug
    errors.add :slug, *errors.delete(:friendly_id) if errors[:friendly_id].present?
  end

  def enforce_transparency_eligibility
    unless eligible_for_transparency?
      self.is_public = false
      self.is_indexable = false
    end

    unless eligible_for_indexing?
      self.is_indexable = false
    end
  end

end
