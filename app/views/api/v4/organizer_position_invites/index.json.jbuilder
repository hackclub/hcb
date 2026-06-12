# frozen_string_literal: true

pagination_metadata(json)
json.data @invitations, partial: "api/v4/invitations/invitation", as: :invitation
