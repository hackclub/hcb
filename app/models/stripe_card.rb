# frozen_string_literal: true

# == Schema Information
#
# Table name: stripe_cards
#
#  id                                    :bigint           not null, primary key
#  canceled_at                           :datetime
#  card_type                             :integer          default("virtual"), not null
#  cash_withdrawal_enabled               :boolean          default(FALSE)
#  initially_activated                   :boolean          default(FALSE), not null
#  is_platinum_april_fools_2023          :boolean
#  last4                                 :text
#  lost_in_shipping                      :boolean          default(FALSE)
#  name                                  :string
#  purchased_at                          :datetime
#  spending_limit_amount                 :integer
#  spending_limit_interval               :integer
#  stripe_brand                          :text
#  stripe_exp_month                      :integer
#  stripe_exp_year                       :integer
#  stripe_shipping_address_city          :text
#  stripe_shipping_address_country       :text
#  stripe_shipping_address_line1         :text
#  stripe_shipping_address_line2         :text
#  stripe_shipping_address_postal_code   :text
#  stripe_shipping_address_state         :text
#  stripe_shipping_name                  :text
#  stripe_status                         :text
#  created_at                            :datetime         not null
#  updated_at                            :datetime         not null
#  event_id                              :bigint           not null
#  last_frozen_by_id                     :bigint
#  replacement_for_id                    :bigint
#  stripe_card_personalization_design_id :integer
#  stripe_cardholder_id                  :bigint           not null
#  stripe_id                             :text
#  subledger_id                          :bigint
#
# Indexes
#
#  index_stripe_cards_on_event_id              (event_id)
#  index_stripe_cards_on_last_frozen_by_id     (last_frozen_by_id)
#  index_stripe_cards_on_replacement_for_id    (replacement_for_id)
#  index_stripe_cards_on_stripe_cardholder_id  (stripe_cardholder_id)
#  index_stripe_cards_on_stripe_id             (stripe_id) UNIQUE
#  index_stripe_cards_on_subledger_id          (subledger_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (last_frozen_by_id => users.id)
#  fk_rails_...  (stripe_cardholder_id => stripe_cardholders.id)
#
class StripeCard < ApplicationRecord
  include Hashid::Rails
  hashid_config salt: ""

  include PublicIdentifiable
  include Freezable
  set_public_id_prefix :crd

  include HasStripeDashboardUrl
  has_stripe_dashboard_url "issuing/cards", :stripe_id

  has_paper_trail

  validate :within_card_limit, on: :create
  validates :subledger, uniqueness: true, allow_nil: true

  after_create_commit :notify_user, unless: :skip_notify_user

  attr_accessor :skip_notify_user

  scope :deactivated, -> { where.not(stripe_status: "active") }
  scope :canceled, -> { where(stripe_status: "canceled") }
  scope :frozen, -> { where(stripe_status: "inactive", initially_activated: true) }
  scope :active, -> { where(stripe_status: "active") }
  scope :inactive, -> { where(stripe_status: "inactive", initially_activated: false) }
  scope :platinum, -> { where(is_platinum_april_fools_2023: true) }

  scope :on_main_ledger, -> { where(subledger_id: nil) }

  belongs_to :event
  belongs_to :subledger, optional: true
  belongs_to :stripe_cardholder
  belongs_to :last_frozen_by, class_name: "User", optional: true
  belongs_to :replacement_for, class_name: "StripeCard", optional: true
  belongs_to :personalization_design, foreign_key: "stripe_card_personalization_design_id", class_name: "StripeCard::PersonalizationDesign", optional: true
  validates_presence_of :stripe_card_personalization_design_id, unless: -> { self.virtual? }, on: :create
  has_one :replacement, class_name: "StripeCard", foreign_key: :replacement_for_id
  alias_method :cardholder, :stripe_cardholder
  has_one :user, through: :stripe_cardholder
  has_many :stripe_authorizations
  alias_method :authorizations, :stripe_authorizations
  alias_method :transactions, :stripe_authorizations
  alias_attribute :platinum, :is_platinum_april_fools_2023

  has_one :card_grant, required: false

  alias_attribute :last_four, :last4

  enum :card_type, { virtual: 0, physical: 1 }
  enum :spending_limit_interval, { daily: 0, weekly: 1, monthly: 2, yearly: 3, per_authorization: 4, all_time: 5 }

  delegate :stripe_name, to: :stripe_cardholder

  validates_uniqueness_of :stripe_id

  validates_presence_of :stripe_shipping_address_city,
                        :stripe_shipping_address_country,
                        :stripe_shipping_address_line1,
                        :stripe_shipping_address_postal_code,
                        :stripe_shipping_name,
                        unless: -> { self.virtual? }

  validates_presence_of :stripe_cardholder_id,
                        :card_type,
                        :stripe_id,
                        :stripe_brand,
                        :stripe_exp_month,
                        :stripe_exp_year,
                        :last4,
                        :stripe_status,
                        if: -> { self.stripe_id.present? }

  validate :only_physical_cards_can_be_lost_in_shipping
  validate :only_physical_cards_can_have_personalization_design
  validate :personalization_design_must_be_of_the_same_event
  validates_length_of :name, maximum: 40

  before_save do
    self.canceled_at = Time.now if stripe_status_changed?(to: "canceled")
  end

  def self.cards_in_shipping
    physical.where.not(stripe_status: "canceled")
            .where(initially_activated: false)
            .includes(:user, :event)
            .reject { |c| c.stripe_obj[:shipping][:status] == "delivered" || c.shipping_eta&.past? }
  end

  def full_card_number
    secret_details[:number]
  end

  def cvc
    secret_details[:cvc]
  end

  def url
    Rails.error.unexpected "StripeCard#url used"
    "/stripe_cards/#{hashid}"
  end

  def popover_path
    "/stripe_cards/#{hashid}?frame=true"
  end

  def formatted_card_number
    return hidden_card_number_with_last_four unless virtual?

    full_card_number.scan(/.{4}/).join(" ")
  end

  def hidden_card_number
    "•••• •••• •••• ••••"
  end

  def hidden_cvc
    "•••"
  end

  def hidden_card_number_with_last_four
    return hidden_card_number unless initially_activated?

    "•••• •••• •••• #{last4}"
  end

  def total_spent
    # pending authorizations + settled transactions
    RawPendingStripeTransaction
      .pending
      .where("stripe_transaction->'card'->>'id' = ?", stripe_id)
      .sum(:amount_cents).abs + canonical_transactions.sum(:amount_cents).abs
  end

  def status_text
    return "Frozen" if stripe_status == "inactive" && initially_activated?

    stripe_status.humanize
  end

  alias :state_text :status_text

  def status_badge_type
    s = stripe_status.to_sym
    return :success if s == :active
    return :error if s == :deleted
    return :warning if s == :inactive && !initially_activated?

    :muted
  end

  def state
    status_badge_type
  end

  def freeze!(frozen_by: User.system_user)
    StripeService::Issuing::Card.update(self.stripe_id, status: :inactive)
    sync_from_stripe!
    self.last_frozen_by = frozen_by
    save!
  end

  def defrost!
    StripeService::Issuing::Card.update(self.stripe_id, status: :active)
    sync_from_stripe!
    save!
    card_grant.update(one_time_use: false) if card_grant&.one_time_use
  end

  def cancel!
    StripeService::Issuing::Card.update(self.stripe_id, status: :canceled)
    sync_from_stripe!
    save!
    card_grant.cancel! if card_grant&.active?
  end

  def frozen?
    initially_activated? && stripe_status == "inactive"
  end

  def active?
    stripe_status == "active"
  end

  def inactive?
    !initially_activated? && stripe_status == "inactive"
  end

  def canceled?
    stripe_status == "canceled"
  end

  include ActiveModel::AttributeMethods
  alias_attribute :address_line1, :stripe_shipping_address_line1
  alias_attribute :address_line2, :stripe_shipping_address_line2
  alias_attribute :address_city, :stripe_shipping_address_city
  alias_attribute :address_state, :stripe_shipping_address_state
  alias_attribute :address_country, :stripe_shipping_address_country
  alias_attribute :address_postal_code, :stripe_shipping_address_postal_code

  def stripe_obj
    @stripe_obj ||= ::Stripe::Issuing::Card.retrieve(id: stripe_id)
  rescue => e
    OpenStruct.new(
      number: "XXXX",
      cvc: "XXX",
      created: Time.now.utc.to_i,
      shipping: OpenStruct.new(
        status: "delivered",
        carrier: "USPS",
        eta: 2.weeks.ago,
        tracking_number: "12345678s9"
      )
    )
  end

  def secret_details
    @secret_details ||= ::Stripe::Issuing::Card.retrieve(id: stripe_id, expand: ["cvc", "number"])
  rescue => e
    OpenStruct.new({ number: "XXXX", cvc: "XXX" })
  end

  def shipping_has_tracking?
    stripe_obj&.shipping&.tracking_number&.present?
  end

  def shipping_eta
    return unless (stripe_eta = stripe_obj&.shipping&.eta)

    # We've found Stripe's ETA for USPS standard is fairly inaccurate. So, I'm
    # padding their estimate to set more realistic expectations for our users.
    Time.at(stripe_eta) + 2.days
  end

  def self.new_from_stripe_id(params)
    raise ArgumentError.new("Only numbers are allowed") unless params[:stripe_id].is_a?(String)

    card = self.new(params)
    card.sync_from_stripe!

    card
  end

  def sync_from_stripe!
    if stripe_obj[:deleted]
      self.stripe_status = "deleted"
      return self
    end
    self.stripe_id = stripe_obj[:id]
    self.stripe_brand = stripe_obj[:brand]
    self.stripe_exp_month = stripe_obj[:exp_month]
    self.stripe_exp_year = stripe_obj[:exp_year]
    self.last4 = stripe_obj[:last4]
    self.stripe_status = stripe_obj[:status]
    self.card_type = stripe_obj[:type]
    # On ~2024-03-26, Stripe introduced personalization designs for physical cards
    # This resulted in older cards not having a personalization design ID.
    # This fix checks if its an old card without a personalization design ID and sets it to the default black design.
    if physical?
      if self.created_at < Time.utc(2024, 3, 27) && stripe_obj[:personalization_design].nil?
        self.stripe_card_personalization_design_id = StripeCard::PersonalizationDesign.default&.id
      else
        self.stripe_card_personalization_design_id = StripeCard::PersonalizationDesign.find_by(stripe_id: stripe_obj[:personalization_design])&.id
      end
    end

    if stripe_obj[:status] == "active"
      self.initially_activated = true
    elsif stripe_obj[:status] == "inactive" && !self.initially_activated
      self.initially_activated = false
    end

    if stripe_obj[:shipping]
      if ["returned", "failure"].include?(stripe_obj[:shipping][:status]) && !lost_in_shipping?
        self.lost_in_shipping = true
        StripeCardMailer.with(card_id: self.id).lost_in_shipping.deliver_later

        # force a refresh of the cache; otherwise, the card will be marked as
        # lost in shipping again since stripe_obj is cached
        @stripe_obj = nil
        self.cancel!

        # `cancel!` calls `sync_from_stripe!`, so there is no need to continue
        return self
      end
      self.stripe_shipping_address_city = stripe_obj[:shipping][:address][:city]
      self.stripe_shipping_address_country = stripe_obj[:shipping][:address][:country]
      self.stripe_shipping_address_line1 = stripe_obj[:shipping][:address][:line1]
      self.stripe_shipping_address_postal_code = stripe_obj[:shipping][:address][:postal_code]
      self.stripe_shipping_address_line2 = stripe_obj[:shipping][:address][:line2]
      self.stripe_shipping_address_state = stripe_obj[:shipping][:address][:state]
      self.stripe_shipping_name = stripe_obj[:shipping][:name]
    end

    spending_limits = stripe_obj[:spending_controls][:spending_limits]
    if spending_limits.any?
      self.spending_limit_interval = spending_limits.first[:interval]
      self.spending_limit_amount = spending_limits.first[:amount]
    end

    if stripe_obj[:replacement_for]
      self.replacement_for = StripeCard.find_by(stripe_id: stripe_obj[:replacement_for])
    end

    self
  end

  def canonical_transactions
    @canonical_transactions ||= CanonicalTransaction.stripe_transaction.where("raw_stripe_transactions.stripe_transaction->>'card' = ?", stripe_id)
  end

  def all_hcb_codes
    canonical_transaction_hcb_codes + canonical_pending_transaction_hcb_codes
  end

  def local_hcb_codes
    @local_hcb_codes ||= ::HcbCode.where(hcb_code: all_hcb_codes).includes(:tags)
  end

  def remote_shipping_status
    return nil if virtual?

    stripe_obj[:shipping][:status]
  end

  def canonical_pending_transaction_hcb_codes
    CanonicalPendingTransaction.joins(:raw_pending_stripe_transaction)
                               .where("raw_pending_stripe_transactions.stripe_transaction->'card'->>'id' = ?", stripe_id)
                               .pluck(:hcb_code)
  end

  def active_spending_control
    return @active_spending_control if defined?(@active_spending_control)

    @active_spending_control = event.organizer_positions.find_by(user:)&.active_spending_control
  end

  def balance_available
    if subledger.present?
      subledger.balance_cents
    elsif active_spending_control
      [active_spending_control.balance_cents, event.balance_available_v2_cents].min
    else
      event.balance_available_v2_cents
    end
  end

  def expired?
    Time.now.utc > Time.new(stripe_exp_year, stripe_exp_month).end_of_month
  end

  def ephemeral_key(nonce:, stripe_version: "2020-03-02")
    Stripe::EphemeralKey.create({ nonce:, issuing_card: stripe_id }, { stripe_version: })
  end

  private

  def canonical_transaction_hcb_codes
    @canonical_transaction_hcb_codes ||= canonical_transactions.pluck(:hcb_code)
  end

  def issued?
    stripe_id.present?
  end

  def notify_user
    if virtual? && card_grant.nil?
      StripeCardMailer.with(card_id: self.id).virtual_card_ordered.deliver_later
    elsif physical?
      StripeCardMailer.with(card_id: self.id).physical_card_ordered.deliver_later
    end
  end

  def authorizations_from_stripe
    @auths ||= begin
      result = []
      auths = StripeService::Issuing::Authorization.list(card: stripe_id)
      auths.auto_paging_each { |auth| result << auth }
      result
    end

    @auths
  end

  def only_physical_cards_can_be_lost_in_shipping
    if !physical? && lost_in_shipping?
      errors.add(:lost_in_shipping, "can only be true for physical cards")
    end
  end

  def only_physical_cards_can_have_personalization_design
    if !physical? && personalization_design.present?
      errors.add(:personalization_design, "can only be add to for physical cards")
    end
  end

  def personalization_design_must_be_of_the_same_event
    if personalization_design&.event.present? && personalization_design.event != event
      errors.add(:personalization_design, "must be of the same event")
    end
  end

  def within_card_limit
    return if subledger.present?

    # card grants don't count against the limit, hence the subledger_id: nil check
    user_cards_today = user.stripe_cards.where(subledger_id: nil, created_at: 1.day.ago..).count
    event_cards_today = event.stripe_cards.where(subledger_id: nil, created_at: 1.day.ago..).count

    if user_cards_today > 20
      errors.add(:base, "Your account has been rate-limited from creating new cards. Please try again tomorrow; for help, email hcb@hackclub.com.")
    end

    if event_cards_today > 20
      errors.add(:base, "Your organization has been rate-limited from creating new cards. Please try again tomorrow; for help, email hcb@hackclub.com.")
    end
  end

  # https://stripe.com/docs/issuing/categories
  STRIPE_MERCHANT_CATEGORIES = %w[
    ac_refrigeration_repair
    accounting_bookkeeping_services
    advertising_services
    agricultural_cooperative
    airlines_air_carriers
    airports_flying_fields
    ambulance_services
    amusement_parks_carnivals
    antique_reproductions
    antique_shops
    aquariums
    architectural_surveying_services
    art_dealers_and_galleries
    artists_supply_and_craft_shops
    auto_and_home_supply_stores
    auto_body_repair_shops
    auto_paint_shops
    auto_service_shops
    automated_cash_disburse
    automated_fuel_dispensers
    automobile_associations
    automotive_parts_and_accessories_stores
    automotive_tire_stores
    bail_and_bond_payments
    bakeries
    bands_orchestras
    barber_and_beauty_shops
    betting_casino_gambling
    bicycle_shops
    billiard_pool_establishments
    boat_dealers
    boat_rentals_and_leases
    book_stores
    books_periodicals_and_newspapers
    bowling_alleys
    bus_lines
    business_secretarial_schools
    buying_shopping_services
    cable_satellite_and_other_pay_television_and_radio
    camera_and_photographic_supply_stores
    candy_nut_and_confectionery_stores
    car_and_truck_dealers_new_used
    car_and_truck_dealers_used_only
    car_rental_agencies
    car_washes
    carpentry_services
    carpet_upholstery_cleaning
    caterers
    charitable_and_social_service_organizations_fundraising
    chemicals_and_allied_products
    child_care_services
    childrens_and_infants_wear_stores
    chiropodists_podiatrists
    chiropractors
    cigar_stores_and_stands
    civic_social_fraternal_associations
    cleaning_and_maintenance
    clothing_rental
    colleges_universities
    commercial_equipment
    commercial_footwear
    commercial_photography_art_and_graphics
    commuter_transport_and_ferries
    computer_network_services
    computer_programming
    computer_repair
    computer_software_stores
    computers_peripherals_and_software
    concrete_work_services
    construction_materials
    consulting_public_relations
    correspondence_schools
    cosmetic_stores
    counseling_services
    country_clubs
    courier_services
    court_costs
    credit_reporting_agencies
    cruise_lines
    dairy_products_stores
    dance_hall_studios_schools
    dating_barroom_services
    dentists_orthodontists
    department_stores
    detective_agencies
    digital_goods_applications
    digital_goods_games
    digital_goods_large_volume
    digital_goods_media
    direct_marketing_catalog_merchant
    direct_marketing_combination_catalog_and_retail_merchant
    direct_marketing_inbound_telemarketing
    direct_marketing_insurance_services
    direct_marketing_other
    direct_marketing_outbound_telemarketing
    direct_marketing_subscription
    direct_marketing_travel
    discount_stores
    doctors
    door_to_door_sales
    drapery_window_covering_and_upholstery_stores
    drinking_places
    drug_stores_and_pharmacies
    drugs_drug_proprietaries_and_druggist_sundries
    dry_cleaners
    durable_goods
    duty_free_stores
    eating_places_restaurants
    educational_services
    electric_razor_stores
    electric_vehicle_charging
    electrical_parts_and_equipment
    electrical_services
    electronics_repair_shops
    electronics_stores
    elementary_secondary_schools
    emergency_services_gcas_visa_use_only
    employment_temp_agencies
    equipment_rental
    exterminating_services
    family_clothing_stores
    fast_food_restaurants
    financial_institutions
    fines_government_administrative_entities
    fireplace_fireplace_screens_and_accessories_stores
    floor_covering_stores
    florists
    florists_supplies_nursery_stock_and_flowers
    freezer_and_locker_meat_provisioners
    fuel_dealers_non_automotive
    funeral_services_crematories
    furniture_home_furnishings_and_equipment_stores_except_appliances
    furniture_repair_refinishing
    furriers_and_fur_shops
    general_services
    gift_card_novelty_and_souvenir_shops
    glass_paint_and_wallpaper_stores
    glassware_crystal_stores
    golf_courses_public
    government_licensed_horse_dog_racing_us_region_only
    government_licensed_online_casinos_online_gambling_us_region_only
    government_owned_lotteries_non_us_region
    government_owned_lotteries_us_region_only
    government_services
    grocery_stores_supermarkets
    hardware_equipment_and_supplies
    hardware_stores
    health_and_beauty_spas
    hearing_aids_sales_and_supplies
    heating_plumbing_a_c
    hobby_toy_and_game_shops
    home_supply_warehouse_stores
    hospitals
    hotels_motels_and_resorts
    household_appliance_stores
    industrial_supplies
    information_retrieval_services
    insurance_default
    insurance_underwriting_premiums
    intra_company_purchases
    jewelry_stores_watches_clocks_and_silverware_stores
    landscaping_services
    laundries
    laundry_cleaning_services
    legal_services_attorneys
    luggage_and_leather_goods_stores
    lumber_building_materials_stores
    manual_cash_disburse
    marinas_service_and_supplies
    marketplaces
    masonry_stonework_and_plaster
    massage_parlors
    medical_and_dental_labs
    medical_dental_ophthalmic_and_hospital_equipment_and_supplies
    medical_services
    membership_organizations
    mens_and_boys_clothing_and_accessories_stores
    mens_womens_clothing_stores
    metal_service_centers
    miscellaneous
    miscellaneous_apparel_and_accessory_shops
    miscellaneous_auto_dealers
    miscellaneous_business_services
    miscellaneous_food_stores
    miscellaneous_general_merchandise
    miscellaneous_general_services
    miscellaneous_home_furnishing_specialty_stores
    miscellaneous_publishing_and_printing
    miscellaneous_recreation_services
    miscellaneous_repair_shops
    miscellaneous_specialty_retail
    mobile_home_dealers
    motion_picture_theaters
    motor_freight_carriers_and_trucking
    motor_homes_dealers
    motor_vehicle_supplies_and_new_parts
    motorcycle_shops_and_dealers
    motorcycle_shops_dealers
    music_stores_musical_instruments_pianos_and_sheet_music
    news_dealers_and_newsstands
    non_fi_money_orders
    non_fi_stored_value_card_purchase_load
    nondurable_goods
    nurseries_lawn_and_garden_supply_stores
    nursing_personal_care
    office_and_commercial_furniture
    opticians_eyeglasses
    optometrists_ophthalmologist
    orthopedic_goods_prosthetic_devices
    osteopaths
    package_stores_beer_wine_and_liquor
    paints_varnishes_and_supplies
    parking_lots_garages
    passenger_railways
    pawn_shops
    pet_shops_pet_food_and_supplies
    petroleum_and_petroleum_products
    photo_developing
    photographic_photocopy_microfilm_equipment_and_supplies
    photographic_studios
    picture_video_production
    piece_goods_notions_and_other_dry_goods
    plumbing_heating_equipment_and_supplies
    political_organizations
    postal_services_government_only
    precious_stones_and_metals_watches_and_jewelry
    professional_services
    public_warehousing_and_storage
    quick_copy_repro_and_blueprint
    railroads
    real_estate_agents_and_managers_rentals
    record_stores
    recreational_vehicle_rentals
    religious_goods_stores
    religious_organizations
    roofing_siding_sheet_metal
    secretarial_support_services
    security_brokers_dealers
    service_stations
    sewing_needlework_fabric_and_piece_goods_stores
    shoe_repair_hat_cleaning
    shoe_stores
    small_appliance_repair
    snowmobile_dealers
    special_trade_services
    specialty_cleaning
    sporting_goods_stores
    sporting_recreation_camps
    sports_and_riding_apparel_stores
    sports_clubs_fields
    stamp_and_coin_stores
    stationary_office_supplies_printing_and_writing_paper
    stationery_stores_office_and_school_supply_stores
    swimming_pools_sales
    t_ui_travel_germany
    tailors_alterations
    tax_payments_government_agencies
    tax_preparation_services
    taxicabs_limousines
    telecommunication_equipment_and_telephone_sales
    telecommunication_services
    telegraph_services
    tent_and_awning_shops
    testing_laboratories
    theatrical_ticket_agencies
    timeshares
    tire_retreading_and_repair
    tolls_bridge_fees
    tourist_attractions_and_exhibits
    towing_services
    trailer_parks_campgrounds
    transportation_services
    travel_agencies_tour_operators
    truck_stop_iteration
    truck_utility_trailer_rentals
    typesetting_plate_making_and_related_services
    typewriter_stores
    u_s_federal_government_agencies_or_departments
    uniforms_commercial_clothing
    used_merchandise_and_secondhand_stores
    utilities
    variety_stores
    veterinary_services
    video_amusement_game_supplies
    video_game_arcades
    video_tape_rental_stores
    vocational_trade_schools
    watch_jewelry_repair
    welding_repair
    wholesale_clubs
    wig_and_toupee_stores
    wires_money_orders
    womens_accessory_and_specialty_shops
    womens_ready_to_wear_stores
    wrecking_and_salvage_yards
  ].freeze

end
