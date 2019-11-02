module StaticPagesHelper
  def card_to(name, path, options = {})
    badge = options[:badge].to_i > 0 ? badge_for(options[:badge], {class: 'badge--notification'}) : ''
    link_to content_tag(:li,
                        [content_tag(:strong, name), badge].join.html_safe,
                        class: 'card card--item card--hover relative overflow-visible line-height-3'),
            path, method: options[:method]
  end
end
