# frozen_string_literal: true

expand @event do
  json.array! @sponsors, partial: "api/v4/sponsors/sponsor", as: :sponsor
end
