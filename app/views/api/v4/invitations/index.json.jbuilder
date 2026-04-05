# frozen_string_literal: true

json.array! @invitations, partial: "api/v4/invitations/invitation", as: :invitation
