# frozen_string_literal: true

require "cgi"

module EventsHelper
  def events_nav(event = @event, selected: nil)
    items = []

    if policy(event).activation_flow?
      items << {
        name: "Activate",
        path: event_activation_flow_path(event_id: event.slug),
        tooltip: "Activate this organization",
        icon: "checkmark",
        selected: selected == :activation_flow,
        adminTool: true,
      }
    end

    if policy(event).show?
      items << {
        name: "Home",
        path: event_path(id: event.slug),
        tooltip: "See everything at-a-glance",
        icon: "home",
        selected: selected == :home,
      }
    end

    if policy(event).announcement_overview?
      items << {
        name: "Announcements",
        path: event_announcement_overview_path(event_id: event.slug),
        tooltip: "View your announcements",
        icon: "announcement",
        selected: selected == :announcements,
      }
    end

    if policy(event).transactions?
      items << {
        name: "Transactions",
        path: event_transactions_path(event_id: event.slug),
        tooltip: "View detailed ledger",
        icon: "bank-account",
        selected: selected == :transactions,
      }
    end

    if policy(event).account_number?
      items << {
        name: "Account numbers",
        path: account_number_event_path(event),
        tooltip: "View account numbers",
        icon: "hashtag",
        selected: selected == :account_number,
      }
    end

    if policy(event).donation_overview? || policy(event).invoices? || policy(event.check_deposits.build).index?
      items << { section: "Receive" }
    end

    if policy(event).donation_overview?
      items << {
        name: "Donations",
        path: event_donation_overview_path(event_id: event.slug),
        tooltip: "Support this organization",
        icon: "support",
        data: { tour_step: "donations" },
        selected: selected == :donations,
      }
    end

    if policy(event).invoices?
      items << {
        name: "Invoices",
        path: event_invoices_path(event_id: event.slug),
        tooltip: "Collect sponsor payments",
        icon: "payment-docs",
        selected: selected == :invoices,
      }
    end

    if policy(event.check_deposits.build).index?
      items << {
        name: "Check deposits",
        path: event_check_deposits_path(event),
        tooltip: "Deposit a check",
        icon: "cheque",
        selected: selected == :deposit_check,
      }
    end

    if policy(event).card_overview? || policy(event).card_grant_overview? || policy(event).transfers? || policy(event).reimbursements? || policy(event).employees?
      items << { section: "Spend" }
    end

    if policy(event).card_overview?
      items << {
        name: "Cards",
        path: event_cards_overview_path(event_id: event.slug),
        tooltip: "Manage team HCB cards",
        icon: "card",
        data: { tour_step: "cards" },
        selected: selected == :cards,
      }
    end

    if policy(event).card_grant_overview?
      items << {
        name: "Grants",
        path: event_card_grant_overview_path(event_id: event.slug),
        tooltip: "Manage card grants",
        icon: "bag",
        selected: selected == :card_grants
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

    if policy(event).employees?
      items << {
        name: "Contractors",
        path: event_employees_path(event_id: event.slug),
        tooltip: "Manage payroll",
        icon: "person-badge",
        selected: selected == :payroll
      }
    end

    if policy(event).team? || policy(event).promotions? || policy(event).g_suite_overview? || policy(event).documentation? || policy(event).sub_organizations?
      items << { section: "" }
    end

    if policy(event).team?
      items << {
        name: "Team",
        path: event_team_path(event_id: event.slug),
        tooltip: "Manage your team",
        icon: "people-2",
        selected: selected == :team,
      }
    end

    if policy(event).promotions?
      items << {
        name: "Perks",
        path: event_promotions_path(event_id: event.slug),
        tooltip: !policy(event).promotions? ? "Your account isn't eligble for receive promos & discounts" : "Receive promos & discounts",
        icon: "perks",
        data: { tour_step: "perks" },
        disabled: !policy(event).promotions?,
        selected: selected == :promotions,
      }
    end

    if policy(event).g_suite_overview?
      items << {
        name: "Google Workspace",
        path: event_g_suite_overview_path(event_id: event.slug),
        tooltip: (if !policy(event).g_suite_overview?
                    "Your organization isn't eligible for Google Workspace."
                  else
                    if event.g_suites.any?
                      "Manage domain Google Workspace"
                    else
                      Flipper.enabled?(:google_workspace, event) ? "Set up domain Google Workspace" : "Register for Google Workspace Waitlist"
                    end
                  end),
        icon: "google",
        disabled: !policy(event).g_suite_overview?,
        selected: selected == :google_workspace,
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

    if policy(event).sub_organizations?
      items << {
        name: "Sub-organizations",
        path: event_sub_organizations_path(event_id: event.slug),
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

    icon_wrapper =
      if icon_tag || badge_tag
        content_tag(:div, class: "dock__item-icon-wrapper") do
          safe_join([icon_tag, badge_tag].compact)
        end
      end

    children = []
    children << icon_wrapper if icon_wrapper
    children << tag.span(name, class: "dock__item-label")
    children = safe_join(children)

    if admin && !auditor_signed_in?
      return ""
    end

    link_to children, (disabled ? "javascript:" : url), options.merge(
      class: "dock__item #{"tooltipped tooltipped--e" if tooltip} #{"disabled" if disabled} #{"admin-tools" if admin}",
      'aria-label': tooltip,
      'aria-current': selected ? "page" : "false",
      'aria-disabled': disabled ? "true" : "false",
    )
  end

  def show_mock_data?(event = @event)
    false
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
    less = params["#{base}_after"]
    greater = params["#{base}_before"]
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

  def subevent_svg_graph(root, all_events)
    node_w  = 160
    node_h  = 36
    h_gap   = 60
    v_gap   = 16
    padding = 24

    all_ids = all_events.map(&:id).to_set

    children_of = Hash.new { |h, k| h[k] = [] }
    all_events.each do |e|
      next if e.id == root.id
      children_of[e.parent_id] << e if all_ids.include?(e.parent_id)
    end
    children_of.each_value { |arr| arr.sort_by!(&:name) }

    # Count leaves in each subtree so we know how much vertical space each node needs
    leaf_count = {}
    count_leaves = lambda do |event|
      children = children_of[event.id]
      leaf_count[event.id] = children.empty? ? 1 : children.sum { |c| count_leaves.call(c) }
    end
    count_leaves.call(root)

    # Top-aligned layout: parent sits at the top of its children group.
    # y_tops maps event.id -> top y of that node's rect.
    y_tops = {}
    assign_y = lambda do |event, top|
      y_tops[event.id] = top
      cursor = top
      children_of[event.id].each do |child|
        assign_y.call(child, cursor)
        cursor += leaf_count[child.id] * (node_h + v_gap)
      end
    end
    assign_y.call(root, padding)

    depths = {}
    queue = [[root, 0]]
    until queue.empty?
      event, depth = queue.shift
      depths[event.id] = depth
      children_of[event.id].each { |c| queue << [c, depth + 1] }
    end

    num_leaves = leaf_count[root.id]
    max_depth  = depths.values.max || 0
    svg_width  = (max_depth + 1) * (node_w + h_gap) - h_gap + 2 * padding
    svg_height = num_leaves * (node_h + v_gap) - v_gap + 2 * padding

    svg = []
    svg << %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{svg_width} #{svg_height}" style="display:block;width:100%;min-width:300px">)
    svg << <<~DEFS
      <defs>
        <marker id="arr" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto">
          <polygon class="arrow-head" points="0 0,8 3,0 6"/>
        </marker>
      </defs>
      <style>
        .node-rect  { fill: #fff; stroke: #ddd; transition: fill 0.15s, stroke 0.15s; }
        .node-text  { fill: #000; font-size: 15px; font-family: system-ui, -apple-system, sans-serif; }
        .root-text  { fill: #fff; font-size: 15px; font-family: system-ui, -apple-system, sans-serif; }
        .edge       { stroke: #aaa; }
        .arrow-head { fill: #aaa; }
        a { outline: none; }
        a:hover .node-rect  { fill: #f0f0f0; stroke: #bbb; }
        a:hover .root-rect  { fill: #d42f47; }
        a:focus .node-rect  { fill: #f0f0f0; stroke: #ec3750; }
        a:focus .root-rect  { stroke: #ff8896; }
        a:active .node-rect { fill: #e0e0e0; stroke: #ec3750; }
        a:active .root-rect { fill: #b02030; }
        [data-dark='true'] .node-rect          { fill: #2a2a2f; stroke: #444; }
        [data-dark='true'] .node-text          { fill: #fff; }
        [data-dark='true'] .edge               { stroke: #555; }
        [data-dark='true'] .arrow-head         { fill: #555; }
        [data-dark='true'] a:hover .node-rect  { fill: #3a3a40; stroke: #666; }
        [data-dark='true'] a:hover .root-rect  { fill: #d42f47; }
        [data-dark='true'] a:focus .node-rect  { fill: #3a3a40; stroke: #ec3750; }
        [data-dark='true'] a:focus .root-rect  { stroke: #ff8896; }
        [data-dark='true'] a:active .node-rect { fill: #1a1a1f; stroke: #ec3750; }
        [data-dark='true'] a:active .root-rect { fill: #b02030; }
      </style>
    DEFS

    # Edges: right-center of parent -> left-center of child
    all_events.each do |event|
      next if children_of[event.id].empty?
      ex = padding + depths[event.id] * (node_w + h_gap) + node_w
      ey = y_tops[event.id] + node_h / 2
      children_of[event.id].each do |child|
        cx2 = padding + depths[child.id] * (node_w + h_gap)
        cy2 = y_tops[child.id] + node_h / 2
        svg << %(<line class="edge" x1="#{ex}" y1="#{ey}" x2="#{cx2}" y2="#{cy2}" stroke-width="1.5" marker-end="url(#arr)"/>)
      end
    end

    # Nodes
    all_events.each do |event|
      x       = padding + depths[event.id] * (node_w + h_gap)
      y       = y_tops[event.id]
      cx      = x + node_w / 2
      cy      = y + node_h / 2
      is_root = event.id == root.id

      rect_attrs = is_root ? %( class="root-rect" fill="#ec3750" stroke="#c0392b") : %( class="node-rect")
      text_class = is_root ? "root-text" : "node-text"
      rx         = is_root ? "18" : "6"
      href       = is_root ? event_sub_organizations_path(root) : event_path(event)
      label      = event.name.length > 21 ? "#{event.name.first(20)}…" : event.name

      svg << %(<a href="#{h(href)}" title="#{h(event.name)}">)
      svg << %(<rect#{rect_attrs} x="#{x}" y="#{y}" width="#{node_w}" height="#{node_h}" rx="#{rx}" stroke-width="2"/>)
      svg << %(<text class="#{text_class}" x="#{cx}" y="#{cy}" text-anchor="middle" dominant-baseline="central">#{h(label)}</text>)
      svg << %(</a>)
    end

    svg << %(</svg>)
    svg.join("\n").html_safe
  end

end
