# frozen_string_literal: true

module EmburseCardsHelper
  def emburse_card_mention(emburse_card)
    icon = inline_icon "card", size: 24, class: "purple pr1"
    if organizer_signed_in?
      text = content_tag :span, emburse_card.last_four
      return link_to(emburse_card, class: "mention") { icon + text }
    else
      text = content_tag :span, "XXXX"
      return link_to(root_path, class: "mention") { icon + text }
    end
  end
end
