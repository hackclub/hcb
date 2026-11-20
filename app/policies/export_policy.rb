# frozen_string_literal: true

class ExportPolicy < ApplicationPolicy
  def download?
    record.parameters&.fetch("public_only", false) == true || (user.present? && user == record.requested_by)
  end

end
