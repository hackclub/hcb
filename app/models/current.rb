# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :session

  # By default, this attribute has an unpersisted Governance::RequestContext.
  # Controllers/models can choose to save it to the database as needed.
  attribute :governance_request_context
  attribute :request_ip # Used by Doorkeeper to capture IP on token creation

  # Managed by FirstController but used across many layouts and partials
  # to render HCB's structure even when signed out / unverified
  attribute :unverified_user

  def user
    session&.user
  end

end
