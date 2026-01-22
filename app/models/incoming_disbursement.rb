# frozen_string_literal: true

# Virtual model wrapping Disbursement, presenting the destination_event perspective.
# This enables a single event_id interface matching IncreaseCheck, AchTransfer, and Wire.
#
# HCB Code: HCB-502-{disbursement_id}
class IncomingDisbursement
  include ActiveModel::Model
  include ActiveModel::Attributes

  def initialize(disbursement)
    @disbursement = disbursement
  end

  # The event this disbursement belongs to (destination perspective)
  def event
    @disbursement.destination_event
  end

  # Positive amount (money arriving at the destination event)
  def amount_cents
    @disbursement.amount
  end

  alias_method :amount, :amount_cents

  def name
    @disbursement.name
  end

  def hcb_code
    "HCB-#{TransactionGroupingEngine::Calculate::HcbCode::INCOMING_DISBURSEMENT_CODE}-#{@disbursement.id}"
  end

  def local_hcb_code
    @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
  end

  def canonical_transactions
    @canonical_transactions ||= CanonicalTransaction.where(hcb_code:)
  end

  def state
    @disbursement.state
  end

  def state_text
    @disbursement.state_text
  end

  def state_icon
    @disbursement.state_icon
  end

  # Returns the corresponding OutgoingDisbursement for the source event
  def outgoing_disbursement
    OutgoingDisbursement.new(@disbursement)
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
           :transaction_memo,
           to: :@disbursement

  # Comparison - two IncomingDisbursements are equal if they wrap the same disbursement
  def ==(other)
    other.is_a?(IncomingDisbursement) && @disbursement.id == other.send(:disbursement).id
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
