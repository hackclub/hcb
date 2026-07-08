# frozen_string_literal: true

module StaticPagesHelper
  extend ActionView::Helpers::NumberHelper

  def card_to(name, path, **options)
    badge = if options[:badge].present?
              badge_for(options[:badge], class: options[:subtle_badge].present? || options[:badge] == 0 ? "bg-muted h-fit" : "bg-accent h-fit")
            elsif options[:async_badge].present?
              turbo_frame_tag options[:async_badge], src: admin_task_size_path(task_name: options[:async_badge]) do
                badge_for "⏳", class: "bg-muted"
              end
            else
              content_tag(:div, "") # Empty div if no badge is present
            end
    pin = inline_icon("pin", class: "pin transition-opacity group-hover:opacity-100 absolute top-0 right-0", size: 24, ':color': "isPinned($el.closest('a').parentElement.id) ? 'orange' : 'var(--muted)'", '@click.prevent': "pin($el.closest('a').parentElement.id, $el.closest('.grid').id)", ":class": "isPinned($el.closest('a').parentElement.id) ? 'opacity-100' : 'opacity-0'")
    content_tag(:div, id: "card-#{name.parameterize}", class: "group relative") do
      link_to content_tag(:div,
                          [
                            content_tag(:strong, sanitize(name), class: "card-name"),
                            pin,
                            content_tag(:span, "", style: "flex-grow: 1"),
                            badge,
                            inline_icon("view-forward", size: 24, class: "ml-1 -mr-2 muted fill-current")
                          ].join.html_safe,
                          class: "card card--hover flex justify-between items-center"),
              path, class: "link-reset", method: options[:method]
    end
  end

  def flavor_text
    FlavorTextService.new(user: current_user).generate
  end

  def link_to_airtable_task(task_name)
    airtable_info[task_name][:destination]
  end

  # Every admin task card points at a single Airtable base, configured via the
  # AIRTABLE_BASE env var. Run `node scripts/setup_airtable_base.mjs` to create
  # the tables below in that base; it writes their ids to config/airtable_tables.json,
  # which is used to deep-link the card destinations.
  def airtable_info
    base = Credentials.fetch(:AIRTABLE_BASE)
    {
      bank_applications: airtable_task(base, :bank_applications, table: "Events",
                                       query: { filterByFormula: "OR(Status='⭐️ New Application', Status='Applied - Approved', Status='Applied - Need Rejection')" }),
      stickers: airtable_task(base, :stickers, table: "Bank%20Stickers",
                              query: { filterByFormula: "Status='Pending'" }),
      domains: airtable_task(base, :domains, table: "Domains",
                             query: { filterByFormula: "Status='Pending'" }),
      onepassword: airtable_task(base, :onepassword, table: "1Password",
                                 query: { filterByFormula: "Status='Pending'" }),
      pvsa: airtable_task(base, :pvsa, table: "PVSA%20Order",
                          query: { filterByFormula: "Status='Pending'" }),
      theeventhelper: airtable_task(base, :theeventhelper, table: "Event%20Insurance",
                                    query: { filterByFormula: "Status='Pending'" }),
      wire_transfers: airtable_task(base, :wire_transfers, table: "Wire%20Transfers",
                                    query: { filterByFormula: "Status='Pending'" }),
      disputed_transactions: airtable_task(base, :disputed_transactions, table: "Disputed%20Transactions",
                                           query: { filterByFormula: "Status='Pending'" }),
      feedback: airtable_task(base, :feedback, table: "Feedback",
                              query: { filterByFormula: "Status='Pending'" }),
      google_workspace_waitlist: airtable_task(base, :google_workspace_waitlist, table: "Google%20Workspace%20Waitlist",
                                               query: { filterByFormula: "Status='Pending'" }),
      you_ship_we_ship: airtable_task(base, :you_ship_we_ship, table: "Users",
                                      query: { filterByFormula: "{Verification Status}='Unknown'" }),
      marketing_shipment_request: airtable_task(base, :marketing_shipment_request, table: "Warehouse%20SKUs")
    }
  end

  # Builds a task entry pointing at the configured base. The destination deep-links
  # to the specific table when its id is known (see config/airtable_tables.json),
  # otherwise it opens the base itself.
  def airtable_task(base, key, table:, query: {})
    table_id = airtable_table_ids[key.to_s]
    destination = table_id ? "https://airtable.com/#{base}/#{table_id}" : "https://airtable.com/#{base}"
    { id: base, table:, query:, destination: }
  end

  def airtable_table_ids
    @airtable_table_ids ||= begin
      path = Rails.root.join("config/airtable_tables.json")
      path.exist? ? JSON.parse(path.read) : {}
    end
  end

  def render_permissions(permissions, depth = 0)
    capture do
      permissions.each_with_index do |(k, v), i|

        # Nested title (for feature groups)
        if v.is_a?(Hash)
          concat(content_tag(:tr) do
            content_tag(:th, class: "h#{depth + 2} #{"pt3" unless i.zero?}", style: "padding-left: #{depth * 2}rem") do
              concat k

              if v[:_preface]
                concat content_tag(:span, v[:_preface], class: "muted regular pl2 h5")
              end
            end
          end)

          concat render_permissions(v, depth + 1)

        # Row for feature with permission icons
        elsif v.is_a?(Symbol)
          concat(content_tag(:tr) do
            concat content_tag(:th, k, class: "regular", style: "padding-left: #{depth * 2}rem")

            needed_role_num = OrganizerPosition.roles[v]

            OrganizerPosition.roles.each_value do |role_num|
              if role_num >= needed_role_num
                concat content_tag(:td, "✅")
              else
                concat content_tag(:td, "❌")
              end
            end
          end)
        end

      end
    end
  end
end
