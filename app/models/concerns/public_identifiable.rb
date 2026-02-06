# frozen_string_literal: true

# (@msw) Stripe-like public IDs that don't require adding a column to the database.
module PublicIdentifiable
  extend ActiveSupport::Concern

  # Central registry for public ID lookup
  # Models still call set_public_id_prefix, this is just for admin lookup tool
  # Lazy-loaded to avoid circular dependencies during Rails initialization
  def self.models
    @models ||= {
      ach: AchTransfer,
      act: PublicActivity::Activity,
      apl: Event::Application,
      bfe: BankFee,
      cdg: CardGrant,
      cdp: CheckDeposit,
      chg: Api::Models::CardCharge,
      chk: Check,
      cmt: Comment,
      crd: StripeCard,
      don: Donation,
      frv: FeeRevenue,
      ick: IncreaseCheck,
      inv: Invoice,
      ivt: OrganizerPositionInvite,
      org: Event,
      rct: Receipt,
      rep: Reimbursement::ExpensePayout,
      rme: Reimbursement::Expense,
      rmr: Reimbursement::Report,
      rph: Reimbursement::PayoutHolding,
      spr: Sponsor,
      tag: Tag,
      txn: HcbCode,
      usr: User,
      wir: Wire,
      wse: WiseTransfer,
      xfr: Disbursement
    }.freeze
  end

  included do
    include Hashid::Rails
    class_attribute :public_id_prefix
  end

  def public_id
    "#{self.public_id_prefix}_#{hashid}"
  end

  # Extract prefix from public ID (e.g., "usr_abc123" => :usr)
  def self.parse_components(public_id)
    return unless public_id.is_a?(String)

    components = public_id.split("_", 2)
    return unless components.size == 2
    return if components.first.blank? || components.last.blank?

    {
      prefix: components.first.to_s.downcase.to_sym,
      hashid: components.last
    }
  end

  # Module-level lookup - single interface for admin tools
  def self.find_by_public_id(public_id)
    return unless (components = parse_components(public_id))

    prefix = components[:prefix]
    model_class = models[prefix]
    return nil unless model_class

    model_class.find_by_public_id(public_id)
  end

  module ClassMethods
    def set_public_id_prefix(prefix)
      self.public_id_prefix = prefix.to_s.downcase
    end

    def find_by_public_id(public_id)
      # Return unless we were able to extract the components
      return unless (components = PublicIdentifiable.parse_components(public_id))

      # Prefix must match this model's prefix to prevent cross-model lookup (e.g., "usr_abc123" should not be found by Event)
      return unless components[:prefix].to_s == self.get_public_id_prefix

      # ex. 'org_h1izp'
      find_by_hashid(components[:hashid])
    end

    def find_by_public_id!(id)
      obj = find_by_public_id id
      raise ActiveRecord::RecordNotFound.new(nil, self.name) if obj.nil?

      obj
    end

    def get_public_id_prefix
      return self.public_id_prefix.to_s.downcase if self.public_id_prefix.present?

      raise NotImplementedError, "The #{self.class.name} model includes PublicIdentifiable module, but has not configure it's prefix in `PublicIdentifiable.models`."
    end
  end
end
