# frozen_string_literal: true

require "cgi"

module EventsHelper
  def events_mobile_nav(event = @event, selected: nil)
    items = []

    if Flipper.enabled?(:event_home_page_redesign_2024_09_21, @event)
      items << {
        name: "Home",
        path: event_path(id: event.slug),
        tooltip: "See everything at-a-glance",
        icon: "home",
        selected: selected == :home,
        flipperEnabled: Flipper.enabled?(:event_home_page_redesign_2024_09_21, @event),
      }
    end

    items << {
      name: "Transactions",
      path: event_transactions_path(event_id: event.slug),
      tooltip: "View your transactions",
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
          tooltip: "Activate This Organization",
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
          tooltip: "Receive donations online",
          icon: "support",
          data: { tour_step: "donations" },
          selected: selected == :donations,
        }
    end
    if event.approved? && event.plan.invoices_enabled?
      items << {
        name: "Invoices",
        path: event_invoices_path(event_id: event.slug),
        tooltip: "Request payments from sponsors",
        icon: "payment-docs",
        selected: selected == :invoices,
      }
    end
    if policy(event).account_number?
      items << {
        name: "Account numbers",
        path: account_number_event_path(event),
        tooltip: "Receive payouts from GoFundMe, Shopify, Venmo, and more",
        icon: "bank-account",
        selected: selected == :account_number
      }
    end
    if policy(event.check_deposits.build).index?
      items << {
        name: "Check deposits",
        path: event_check_deposits_path(event),
        tooltip: "Deposit checks",
        icon: "cheque",
        selected: selected == :deposit_check,
      }
    end
    if policy(@event).transfers? || policy(@event).reimbursements? || policy(@event).card_overview? || Flipper.enabled?(:grants_2023_06_21, @event)
      items << { section: "Spend" }
    end
    if policy(event).card_overview?
      items <<
        {
          name: "Cards",
          path: event_cards_overview_path(event_id: event.slug),
          tooltip: "Manage team debit cards",
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

    if Flipper.enabled?(:grants_2023_06_21, event)
      items << {
        name: "Grants",
        path: event_grants_path(event),
        tooltip: "Send & manage grants",
        icon: "idea",
        selected: selected == :grants,
      }
    end
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
    if organizer_signed_in?
      items << {
        name: "Google Workspace",
        path: event_g_suite_overview_path(event_id: event.slug),
        tooltip: if !policy(event).g_suite_overview?
                   "Your organization isn't eligible for Google Workspace."
                 else
                   if @event.g_suites.any?
                     "Manage domain Google Workspace"
                   else
                     Flipper.enabled?(:google_workspace, @event) ? "Set up domain Google Workspace" : "Register for Google Workspace Waitlist"
                   end
                 end,
        icon: "google",
        disabled: !policy(event).g_suite_overview?,
        selected: selected == :google_workspace,
      }
    end
    if policy(event).documentation?
      items << {
        name: "Documents",
        path: event_documents_path(event_id: event.slug),
        tooltip: "View legal documents, financial statements, and FAQ",
        icon: "docs",
        selected: selected == :documentation,
      }
    end

    items
  end

  def dock_item(name, url = nil, icon: nil, tooltip: nil, async_badge: nil, disabled: false, selected: false, admin: false, **options)
    link_to (disabled ? "javascript:" : url), options.merge(
      class: "dock__item #{"dock__item--selected" if selected} #{"tooltipped tooltipped--e" if tooltip} #{"disabled" if disabled}",
      'aria-label': tooltip
    ) do
      (content_tag :div, class: "line-height-0 relative" do
        if async_badge
          inline_icon(icon, size: 32) +
            turbo_frame_tag(async_badge, src: async_badge, data: { controller: "cached-frame", action: "turbo:frame-render->cached-frame#cache" })
        elsif icon.present?
          inline_icon(icon, size: 32)
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
end
