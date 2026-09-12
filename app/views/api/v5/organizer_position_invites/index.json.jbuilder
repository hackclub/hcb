# frozen_string_literal: true

json.data @records, partial: "api/v5/organizer_position_invites/organizer_position_invite", as: :invitation
pagination_metadata(json)
