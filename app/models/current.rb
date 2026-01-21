# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :session

  # By default, this attribute has an unpersisted Governance::RequestContext.
  # Controllers/models can choose to save it to the database as needed.
  attribute :governance_request_context

  def user
    session&.user
  end

end
