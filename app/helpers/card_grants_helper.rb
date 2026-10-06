# frozen_string_literal: true

module CardGrantsHelper
  CARD_GRANT_HELP_CENTER_URL = "https://grants.help.hcb.hackclub.com/en/collections/19675936-card-grants"

  CARD_GRANT_HELP_ARTICLES = {
    getting_started: { label: "How it works", icon: "welcome", tone: "info", url: "https://grants.help.hcb.hackclub.com/en/articles/15410293-i-got-a-card-grant-how-do-i-use-it" },
    declined: { label: "Card declined", icon: "forbidden", tone: "primary", url: "https://grants.help.hcb.hackclub.com/en/articles/15414377-my-grant-card-was-declined-what-can-i-do" },
    personal_purchase: { label: "Personal purchase", icon: "flag", tone: "warning", url: "https://grants.help.hcb.hackclub.com/en/articles/15582008-i-used-my-grant-card-for-a-personal-purchase-by-mistake-what-do-i-do" },
    refund: { label: "Refunds", icon: "view-reload", tone: "success", url: "https://grants.help.hcb.hackclub.com/en/articles/15582011-i-got-a-refund-on-a-grant-purchase-where-does-the-money-go" },
    combine: { label: "Combine grants", icon: "card-list", tone: "info", url: "https://grants.help.hcb.hackclub.com/en/articles/15582012-can-i-combine-multiple-grant-cards" },
    wallet: { label: "Apple & Google Pay", icon: "phone", tone: "accent", url: "https://grants.help.hcb.hackclub.com/en/articles/15582010-can-i-use-my-grant-card-with-apple-pay-or-google-pay" },
    more_money: { label: "Need more money?", icon: "plus", tone: "purple", url: "https://grants.help.hcb.hackclub.com/en/articles/15582009-can-i-add-more-money-to-my-grant-card" },
  }.freeze

  def card_grant_help_url(key)
    CARD_GRANT_HELP_ARTICLES.fetch(key)[:url]
  end

  # The help articles shown as tiles to a grantee. "Combine grants" only means
  # anything to someone with more than one grant, so it's left out otherwise.
  def card_grant_help_tiles(card_grant)
    keys = %i[more_money declined personal_purchase refund]
    keys << :combine if card_grant.user.card_grants.active.where.not(id: card_grant.id).exists?

    CARD_GRANT_HELP_ARTICLES.values_at(*keys)
  end
end
