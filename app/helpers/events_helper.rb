# frozen_string_literal: true

require "cgi"

module EventsHelper
  def dock_item(name, url = nil, icon:, tooltip: nil, async_badge: nil, disabled: false, selected: false, **options)
    link_to (disabled ? "javascript:" : url), options.merge(
      class: "dock__item #{"dock__item--selected" if selected} #{"tooltipped tooltipped--e" if tooltip} #{"disabled" if disabled}",
      'aria-label': tooltip
    ) do
      (content_tag :div, class: "line-height-0 relative" do
        if async_badge
          inline_icon(icon, size: 24) +
          turbo_frame_tag(async_badge, src: async_badge, data: { controller: "cached-frame", action: "turbo:frame-render->cached-frame#cache" })
        else
          inline_icon(icon, size: 24)
        end
      end) + content_tag(:span, name.html_safe, class: "line-height-3")
    end
  end

  def show_mock_data?(event = @event)
    event&.demo_mode? && session[mock_data_session_key]
  end

  def set_mock_data!(bool = true, event = @event)
    session[mock_data_session_key] = bool
  end

  def mock_data_session_key(event = @event)
    "show_mock_data_#{event.id}".to_sym
  end

  def paypal_transfers_airtable_form_url(embed: false, event: nil, user: nil)
    # The airtable form is located within the Bank Promotions base
    form_id = "4j6xJB5hoRus"
    embed_url = "https://forms.hackclub.com/t/#{form_id}"
    url = "https://forms.hackclub.com/t/#{form_id}"

    prefill = []
    prefill << "prefill_Event/Project+Name=#{CGI.escape(event.name)}" if event
    prefill << "prefill_Submitter+Name=#{CGI.escape(user.full_name)}" if user
    prefill << "prefill_Submitter+Email=#{CGI.escape(user.email)}" if user

    "#{embed ? embed_url : url}?#{prefill.join("&")}"
  end

  def transaction_memo(tx) # needed to handle mock data in playground mode
    if tx.local_hcb_code.method(:memo).parameters.size == 0
      tx.local_hcb_code.memo
    else
      tx.local_hcb_code.memo(event: @event)
    end
  end

  def humanize_audit_log_value(field, value)
    if field == "sponsorship_fee"
      return number_to_percentage(value.to_f * 100, significant: true, strip_insignificant_zeros: true)
    end

    if field == "point_of_contact_id"
      return User.find(value).email
    end

    if field == "category" && value.is_a?(Integer) || value.try(:match?, /\A\d+\z/)
      return Event.categories.key(value.to_i)
    end

    if field == "maximum_amount_cents"
      return render_money(value.to_s)
    end

    if field == "event_id"
      return Event.find(value).name
    end

    if field == "reviewer_id"
      return User.find(value).name
    end

    return "Yes" if value == true
    return "No" if value == false

    return value
  end

  def render_audit_log_field(field)
    field.delete_suffix("_cents").humanize
  end

  def render_audit_log_value(field, value, color:)
    return tag.span "unset", class: "muted" if value.nil? || value.try(:empty?)

    return tag.span humanize_audit_log_value(field, value), class: color
  end

  def show_org_switcher?
    signed_in? && current_user.events.not_hidden.count > 1
  end

  def pie_chart_config
    {
      elements: {
        arc: {
          borderWidth: 0
        }
      },
      plugins: {
        legend: {
          position: "right",
          align: "start",
          labels: {
            boxWidth: 10,
            boxHeight: 10,
            usePointStyle: "circle"
          }
        }
      }
    }
  end
end
