# frozen_string_literal: true

require "cgi"

module EventsHelper
  def events_nav(event = @event, selected: nil)
    items = []

    if Flipper.enabled?(:event_home_page_redesign_2024_09_21, @event)
      items << {
        name: "Home",
        path: event_path(id: event.slug),
        tooltip: "See everything at-a-glance",
        icon: "home",
        selected: selected == :home,
      }
    end

    if policy(@event).announcement_overview?
      items << {
        name: "Announcements",
        path: event_announcement_overview_path(event_id: event.slug),
        tooltip: "View your announcements",
        icon: "announcement",
        selected: selected == :announcements,
      }
    end

    items << {
      name: "Transactions",
      path: event_transactions_path(event_id: event.slug),
      tooltip: "View detailed ledger",
      icon: "bank-account",
      selected: selected == :transactions,
    }

    if policy(@event).donation_overview? || ( @event.approved? && @event.plan.invoices_enabled? ) || policy(@event).account_number? || policy(@event.check_deposits.build).index?
      items << { section: "Receive" }
    end

    if policy(event).activation_flow?
      items <<
        {
          name: "Activate",
          path: event_activation_flow_path(event_id: event.slug),
          tooltip: "Activate this organization",
          icon: "checkmark",
          selected: selected == :activation_flow,
          adminTool: true,
        }
    end
    if policy(event).donation_overview?
      items <<
        {
          name: "Donations",
          path: event_donation_overview_path(event_id: event.slug),
          tooltip: "Support this organization",
          icon: "support",
          data: { tour_step: "donations" },
          selected: selected == :donations,
        }
    end
    if event.approved? && event.plan.invoices_enabled?
      items << {
        name: "Invoices",
        path: event_invoices_path(event_id: event.slug),
        tooltip: "Collect sponsor payments",
        icon: "payment-docs",
        selected: selected == :invoices,
      }
    end
    if policy(event).account_number? && !Flipper.enabled?(:event_home_page_redesign_2024_09_21, @event)
      items << {
        name: "Account numbers",
        path: account_number_event_path(event),
        tooltip: "Receive payouts from GoFundMe, Shopify, Venmo, and more",
        icon: "account-numbers",
        selected: selected == :account_number
      }
    end
    if policy(event.check_deposits.build).index? && !Flipper.enabled?(:event_home_page_redesign_2024_09_21, @event)
      items << {
        name: "Check deposits",
        path: event_check_deposits_path(event),
        tooltip: "Deposit checks",
        icon: "cheque",
        selected: selected == :deposit_check,
      }
    end
    if policy(@event).transfers? || policy(@event).reimbursements? || policy(@event).card_overview?
      items << { section: "Spend" }
    end
    if policy(event).card_overview?
      items <<
        {
          name: "Cards",
          path: event_cards_overview_path(event_id: event.slug),
          tooltip: "Manage team HCB cards",
          icon: "card",
          data: { tour_step: "cards" },
          selected: selected == :cards,
        }
    end
    if policy(event).transfers?
      items << {
        name: "Transfers",
        path: event_transfers_path(event_id: event.slug),
        tooltip: "Send & transfer money",
        icon: "payment-transfer",
        selected: selected == :transfers,
      }
    end
    if policy(event).reimbursements?
      items << {
        name: "Reimbursements",
        path: event_reimbursements_path(event_id: event.slug),
        async_badge: event_reimbursements_pending_review_icon_path(event),
        tooltip: "Reimburse team members & volunteers",
        icon: "reimbursement",
        selected: selected == :reimbursements
      }
    end
    if Flipper.enabled?(:payroll_2025_02_13, @event)
      items << {
        name: "Contractors",
        path: event_employees_path(event_id: @event.slug),
        tooltip: "Manage payroll",
        icon: "person-badge",
        selected: selected == :payroll
      }
    end

    items << { section: "" }

    items <<
      {
        name: "Team",
        path: event_team_path(event_id: event.slug),
        tooltip: "Manage your team",
        icon: "people-2",
        selected: selected == :team,
      }
    if event.approved?
      items << {
        name: "Perks",
        path: event_promotions_path(event_id: event.slug),
        tooltip: !policy(event).promotions? ? "Your account isn't eligble for receive promos & discounts" : "Receive promos & discounts",
        icon: "perks",
        data: { tour_step: "perks" },
        disabled: !policy(@event).promotions?,
        selected: selected == :promotions,
      }
    end
    if policy(event).documentation?
      items << {
        name: "Documents",
        path: event_documents_path(event_id: event.slug),
        tooltip: "View legal documents and financial statements",
        icon: "docs",
        selected: selected == :documentation,
      }
    end

    if policy(@event).sub_organizations?
      items << {
        name: "Sub-organizations",
        path: event_sub_organizations_path(event_id: @event.slug),
        tooltip: "Create & manage subsidiary organisations",
        icon: "channels",
        selected: selected == :sub_organizations
      }
    end

    items
  end

  def dock_item(name, url = nil, icon: nil, tooltip: nil, async_badge: nil, disabled: false, selected: false, admin: false, **options)
    icon_tag = icon.present? ? inline_icon(icon, size: 32) : nil
    badge_tag = async_badge.present? ? turbo_frame_tag(async_badge, src: async_badge, data: { controller: "cached-frame", action: "turbo:frame-render->cached-frame#cache" }) : nil
    prefix = icon_tag || badge_tag ? content_tag(:div, icon_tag || badge_tag, class: "line-height-0 relative") : ""
    children = prefix + name.html_safe
    link_to children, (disabled ? "javascript:" : url), options.merge(
      class: "dock__item #{"tooltipped tooltipped--e" if tooltip} #{"disabled" if disabled}",
      'aria-label': tooltip,
      'aria-current': selected ? "page" : "false",
      'aria-disabled': disabled ? "true" : "false",
    )
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

  def transaction_memo(tx)
    # needed to handle mock data in playground mode
    if tx.local_hcb_code.method(:memo).parameters.size == 0
      tx.local_hcb_code.memo
    else
      tx.local_hcb_code.memo(event: @event)
    end
  end

  def humanize_audit_log_value(field, value)

    if field == "point_of_contact_id"
      return User.find(value).email
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
    field.delete_suffix("_cents").humanize
  end

  def render_audit_log_value(field, value, color:)
    return tag.span "unset", class: "muted" if value.nil? || value.try(:empty?)

    return tag.span humanize_audit_log_value(field, value), class: color
  end

  def show_org_switcher?
    signed_in? && current_user.events.not_hidden.count > 1
  end

  def check_filters?(filter_options, params)
    filter_options.any? do |opt|
      key = opt[:key].to_s

      case opt[:type]
      when "date_range"
        params["#{opt[:key_base]}_before"].present? || params["#{opt[:key_base]}_after"].present?
      when "amount_range"
        params["#{opt[:key_base]}_less_than"].present? || params["#{opt[:key_base]}_greater_than"].present?
      else
        params[key].present?
      end
    end
  end

  def validate_filter_options(filter_options, params)
    filter_options.each do |opt|
      case opt[:type]
      when "date_range"
        validate_date_range(opt[:key_base], params)
      when "amount_range"
        validate_amount_range(opt[:key_base], params)
      end
    end
  end

  def auto_discover_feed(event)
    if event.announcements.any?
      content_for :head do
        auto_discovery_link_tag :atom, event_feed_url(event, format: :atom), title: "Announcements for #{event.name}"
      end
    end
  end

  private

  def validate_date_range(base, params)
    less = params["#{base}_before"]
    greater = params["#{base}_after"]
    return unless less.present? && greater.present?

    begin
      less_date = Date.parse(less)
      greater_date = Date.parse(greater)
      if greater_date < less_date
        flash[:error] = "Invalid date range: 'after' date is greater than 'before' date"
      end
    rescue ArgumentError
      flash[:error] = "Invalid date format"
    end
  end

  def validate_amount_range(base, params)
    less = params["#{base}_less_than"]
    greater = params["#{base}_greater_than"]
    return unless less.present? && greater.present?

    if greater.to_f > less.to_f
      flash[:error] = "Invalid amount range: minimum is greater than maximum"
    end
  end

end
