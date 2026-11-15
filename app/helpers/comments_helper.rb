# frozen_string_literal: true

module CommentsHelper
  # The side of a disbursement the commentable is on (a Disbursement::Outgoing or
  # Disbursement::Incoming), for an HcbCode or a Ledger::Item; nil otherwise.
  def disbursement_side_of(commentable)
    case commentable
    when Ledger::Item then commentable.linked_object if commentable.shared_commentable?
    when HcbCode then commentable.outgoing_disbursement || commentable.incoming_disbursement
    end
  end
end
