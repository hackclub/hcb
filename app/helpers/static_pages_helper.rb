# frozen_string_literal: true

module StaticPagesHelper
  extend ActionView::Helpers::NumberHelper

  def card_to(name, path, options = {})
    badge = if options[:badge].present?
              badge_for(options[:badge], class: options[:subtle_badge].present? || options[:badge] == 0 ? "bg-muted h-fit-content" : "bg-accent h-fit-content")
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
                            content_tag(:strong, name, class: "card-name"),
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

  def airtable_info
    {
      grant: {
        id: "appEzv7w2IBMoxxHe",
        table: "Github%20Grant",
        query: { filterByFormula: "Status='Pending'" },
        destination: "https://airtable.com/tblsYQ54Rg1Pjz1xP/viwjETKo05TouqYev"
      },
      onboard_id: {
        id: "app4Bs8Tjwvk5qcD4",
        table: "Verifications%20-%20Depreciated",
        query: { filterByFormula: "Status='Pending'" },
        destination: "https://airtable.com/app4Bs8Tjwvk5qcD4/tblVZwB8QMUSDAd41/viwJ15CT6VHCZ0UZ4"
      },
      bank_applications: {
        id: "apppALh5FEOKkhjLR",
        table: "Events",
        query: { filterByFormula: "OR(Status='⭐️ New Application', Status='Applied - Approved', Status='Applied - Need Rejection')" },
        destination: "https://airtable.com/tblctmRFEeluG4do7/viwGhv19cV1ZRj61a"
      },
      stickers: {
        id: "appEzv7w2IBMoxxHe",
        table: "Bank%20Stickers",
        query: { filterByFormula: "Status='Pending'" },
        destination: "https://airtable.com/tblyhkntth4OyQxiO/viwHcxhOKMZnPXUUU"
      },
      stickermule: {
        id: "appEzv7w2IBMoxxHe",
        table: "StickerMule",
        query: { filterByFormula: "Status='Pending'" },
        destination: "https://airtable.com/tblwYTdp2fiBv7JqA/viwET9tCYBwaZ3NIq"
      },
      replit: {
        id: "appEzv7w2IBMoxxHe",
        table: "Repl.it%20Hacker%20Plan",
        query: { filterByFormula: "Status='Pending'" },
        destination: "https://airtable.com/tbl6cbpdId4iA96mD/viw2T8d98ZhhacHCf"
      },
      domains: {
        id: "appEzv7w2IBMoxxHe",
        table: "Domains",
        query: { filterByFormula: "Status='Pending'" },
        destination: "https://airtable.com/tbl22cXd3Bo9uo0wp/viwcnZyoctJTFGVY2"
      },
      onepassword: {
        id: "appEzv7w2IBMoxxHe",
        table: "1Password",
        query: { filterByFormula: "Status='Pending'" },
        destination: "https://airtable.com/tblcHEZyos3V9DoeI/viwSapKZ8C4ByBuqT"
      },
      pvsa: {
        id: "appEzv7w2IBMoxxHe",
        table: "PVSA%20Order",
        query: { filterByFormula: "Status='Pending'" },
        destination: "https://airtable.com/tbl4ffIbyaEa2fIYW/viw2OPTziXEqOpaLA"
      },
      theeventhelper: {
        id: "appEzv7w2IBMoxxHe",
        table: "Event%20Insurance",
        query: { filterByFormula: "Status='Pending'" },
        destination: "https://airtable.com/tblWlQxkf6L7mEjC4/viwzbku7oWsw5GFEa"
      },
      wire_transfers: {
        id: "appEzv7w2IBMoxxHe",
        table: "Wire%20Transfers",
        query: { filterByFormula: "Status='Pending'" },
        destination: "https://airtable.com/tbloFbH16HI7t3mfG/viwzgt8VLHOC82m8n"
      },
      disputed_transactions: {
        id: "appEzv7w2IBMoxxHe",
        table: "Disputed%20Transactions",
        query: { filterByFormula: "Status='Pending'" },
        destination: "https://airtable.com/appEzv7w2IBMoxxHe/tblTqbwz5AUkzOcVb"
      },
      feedback: {
        id: "appEzv7w2IBMoxxHe",
        table: "Feedback",
        query: { filterByFormula: "Status='Pending'" },
        destination: "https://airtable.com/tblOmqLjWtJZWXn4O/viwuk2j4xsKJo5EqA"
      },
      wallets: {
        id: "appEzv7w2IBMoxxHe",
        table: "Wallets",
        query: { filterByFormula: "Status='Pending'" },
        destination: "https://airtable.com/tblJtjtY9qAOG3FS8/viwUz9aheNAvXwzjg"
      },
      google_workspace_waitlist: {
        id: "appEzv7w2IBMoxxHe",
        table: "Google%20Workspace%20Waitlist",
        query: { filterByFormula: "Status='Pending'" },
        destination: "https://airtable.com/appEzv7w2IBMoxxHe/tbl9CkfZHKZYrXf1T/viwgfJvrrD9Jn9VLj"
      },
      you_ship_we_ship: {
        id: "appre1xwKlj49p0d4",
        table: "Users",
        query: { filterByFormula: "{Verification Status}='Unknown'" },
        destination: "https://airtable.com/appre1xwKlj49p0d4/tbl2Q2aCWqyBGi9mj/viwVYhUQYyNJOi0EH"
      },
      boba: {
        id: "app05mIKwNPO2l1vT",
        table: "Event%20Codes",
        query: { filterByFormula: "Status='Under Review'" },
        destination: "https://airtable.com/app05mIKwNPO2l1vT/tblcIuVemD63IbBuY/viw1Zo5lX8e7t2Vzu"
      },
      marketing_shipment_request: {
        id: "appK53aN0fz3sgJ4w",
        table: "tblvSJMqoXnQyN7co",
        destination: "https://airtable.com/appK53aN0fz3sgJ4w/tblvSJMqoXnQyN7co/viwk107ZoZqAsFfRS"
      }
    }
  end

  def apply_form_url(user = current_user, **query_params)
    query_params = { userEmail: user.email, firstName: user.first_name, lastName: user.last_name, userPhone: user.phone_number, userBirthday: user.birthday&.year, utm_source: "hcb", utm_medium: "web" }.merge(query_params) # allow method arguments to override default.
    "https://hackclub.com/fiscal-sponsorship/apply/?#{URI.encode_www_form(query_params.compact)}"
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
