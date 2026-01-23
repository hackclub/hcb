# frozen_string_literal: true

# Virtual model wrapping Disbursement, presenting the source_event perspective.
# This enables a single event_id interface matching IncreaseCheck, AchTransfer, and Wire.
#
# HCB Code: HCB-501-{disbursement_id}
class OutgoingDisbursement
  include ActiveModel::Model
  include ActiveModel::Attributes

  def initialize(disbursement)
    @disbursement = disbursement
  end

  # The event this disbursement belongs to (source perspective)
  def event
    @disbursement.source_event
  end

  # Negative amount (money leaving the source event)
  def amount_cents
    -@disbursement.amount
  end

  alias_method :amount, :amount_cents

  delegate :name, to: :@disbursement

  def hcb_code
    "HCB-#{TransactionGroupingEngine::Calculate::HcbCode::OUTGOING_DISBURSEMENT_CODE}-#{@disbursement.id}"
  end

  def local_hcb_code
    @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
  end

  def canonical_transactions
    @canonical_transactions ||= CanonicalTransaction.where(hcb_code:)
  end

  def transaction_memo
    "HCB-#{local_hcb_code&.short_code}"
  end

  delegate :state, to: :@disbursement

  delegate :state_text, to: :@disbursement

  delegate :state_icon, to: :@disbursement

  # Returns the corresponding IncomingDisbursement for the destination event
  def incoming_disbursement
    IncomingDisbursement.new(@disbursement)
  end

  # Delegate common methods to the underlying disbursement
  delegate :id,
           :public_id,
           :aasm_state,
           :pending?,
           :reviewing?,
           :in_transit?,
           :deposited?,
           :rejected?,
           :errored?,
           :scheduled?,
           :processed?,
           :fulfilled?,
           :approved_at,
           :transferred_at,
           :pending_expired?,
           :created_at,
           :updated_at,
           :scheduled_on,
           :requested_by,
           :fulfilled_by,
           :source_subledger,
           :destination_subledger,
           :destination_event,
           :source_event,
           :filter_data,
           :special_appearance_name,
           :special_appearance,
           :special_appearance?,
           :special_appearance_memo,
           :fee_waived?,
           to: :@disbursement

  # Comparison - two OutgoingDisbursements are equal if they wrap the same disbursement
  def ==(other)
    other.is_a?(OutgoingDisbursement) && @disbursement.id == other.send(:disbursement).id
  end

  def eql?(other)
    self == other
  end

  def hash
    [@disbursement.id, self.class].hash
  end

  private

  attr_reader :disbursement
end
