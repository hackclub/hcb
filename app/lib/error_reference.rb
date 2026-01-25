# frozen_string_literal: true

module ErrorReference
  def self.from_request_id(request_id)
    return nil unless request_id.present?

    short_id = request_id.to_s.delete("-")[0, 8].upcase
    "ERR-#{short_id}"
  end
end
