# frozen_string_literal: true

module StaticPagesHelper
  extend ActionView::Helpers::NumberHelper

  def card_to(name, path, options = {})
    badge = if options[:badge].present?
              badge_for(options[:badge], class: options[:subtle_badge].present? || options[:badge] == 0 ? "bg-muted pr2 h-fit-content" : "bg-accent pr2 h-fit-content")
            elsif options[:async_badge].present?
              turbo_frame_tag options[:async_badge], src: admin_task_size_path(task_name: options[:async_badge]) do
                badge_for "⏳", class: "bg-muted pr2"
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
                            badge
                          ].join.html_safe,
                          class: "card card--item card--hover flex justify-between items-center"),
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
        table: "Verifications",
        query: { filterByFormula: "Status='Pending'" },
        destination: "https://airtable.com/app4Bs8Tjwvk5qcD4/tblVZwB8QMUSDAd41/viwJ15CT6VHCZ0UZ4"
      },
      bank_applications: {
        id: "apppALh5FEOKkhjLR",
        table: "Events",
        query: { filterByFormula: "Pending='Pending'" },
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
      sendy: {
        id: "appEzv7w2IBMoxxHe",
        table: "Sendy",
        query: { filterByFormula: "Status='Pending'" },
        destination: "https://airtable.com/tbl1MRaNpF4KphbOd/viwb7ELYyxpuAz6gQ"
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
      first_grant: {
        id: "appEzv7w2IBMoxxHe",
        table: "Hackathon%20Grant",
        query: { filterByFormula: "Status='Pending'" },
        destination: "https://airtable.com/tblnNB5iMbidfB552/viwjF8iDPU3gAiXJU"
      },
      wire_transfers: {
        id: "appEzv7w2IBMoxxHe",
        table: "Wire%20Transfers",
        query: { filterByFormula: "Status='Pending'" },
        destination: "https://airtable.com/tbloFbH16HI7t3mfG/viwzgt8VLHOC82m8n"
      },
      paypal_transfers: {
        id: "appEzv7w2IBMoxxHe",
        table: "PayPal%20Transfers",
        query: { filterByFormula: "Status='Pending'" },
        destination: "https://airtable.com/tbloGiW2jhja8ivtV/viwzhAnWYhpFNhvmC"
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
      }
    }
  end

  def apply_form_url(user = current_user)
    "https://hackclub.com/fiscal-sponsorship/apply/?#{URI.encode_www_form({ userEmail: user.email, firstName: user.first_name, lastName: user.last_name, userPhone: user.phone_number, userBirthday: user.birthday&.year }.compact)}"
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

            OrganizerPosition.roles.each do |_role, role_num|
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
