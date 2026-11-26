# frozen_string_literal: true

module AuditLogHelper
  def humanize_audit_log_value(field, value)
    if field == "point_of_contact_id"
      return User.find_by(id: value)&.email || value
    end

    if field == "maximum_amount_cents"
      return render_money(value.to_s)
    end

    if field == "event_id"
      return Event.find_by(id: value)&.name || value
    end

    if field == "reviewer_id"
      return User.find_by(id: value)&.name || value
    end

    return "Yes" if value == true
    return "No" if value == false

    if field.ends_with?("_at")
      begin
        return local_time(value)
      rescue
        return value
      end
    end

    return value
  end

  def render_audit_log_field(field)
    field.delete_suffix("_cents").delete_suffix("_ciphertext").humanize
  end

  def render_audit_log_value(field, value, color:)
    return tag.span "unset", class: "muted" if value.nil? || value.try(:empty?)

    return tag.span humanize_audit_log_value(field, value), class: color
  end
end
