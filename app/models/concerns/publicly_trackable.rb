# frozen_string_literal: true

# Shared concern for models that use the standard PublicActivity tracking
# configuration: owner = current_user, event_id = record.event.id, only create.
#
# Models with non-standard configurations (comment, disbursement, donation,
# event, organizer_position_invite, raw_pending_stripe_transaction, user,
# webauthn_credential) continue to call `tracked` directly.
module PubliclyTrackable
  extend ActiveSupport::Concern

  included do
    include PublicActivity::Model
    tracked owner: proc { |controller, record| controller&.current_user },
            event_id: proc { |controller, record| record.event.id },
            only: [:create]
  end
end
