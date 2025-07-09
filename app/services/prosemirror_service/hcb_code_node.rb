# frozen_string_literal: true

module ProsemirrorService
  class HcbCodeNode < ProsemirrorToHtml::Nodes::Node
    include ApplicationHelper

    @node_type = "hcbCode"
    @tag_name = "div"

    def tag
      [{ tag: self.class.tag_name, attrs: (@node.attrs.to_h || {}).merge({ class: "hcbCode relative card shadow-none border flex flex-col py-2 my-2" }) }]
    end

    def matching
      @node.type == self.class.node_type
    end

    def text
      hcb_code = HcbCode.find_by_hashid(@node.attrs.code)

      if hcb_code.event != ProsemirrorService::Renderer.event
        return "<p>This transaction cannot be displayed</p>"
      end

      <<-HTML.chomp
        <p class="block font-bold flex items-center gap-2 my-0">
          #{hcb_code.date.strftime("%B %e, %Y")}
          #{(hcb_code.pt&.declined? ? (badge_for "Declined", class: "bg-error m0 mr1") : (badge_for "Pending", class: "bg-transparent border border-dashed border-muted m0 mr1")) if hcb_code.canonical_transactions.none?}
        </p>
        <p class="mt1 mb1 line-height-3 h3">
          #{CGI.escape_html(hcb_code.memo)}
        </p>
        <footer class="flex items-center justify-between -mb-1 gap-2 w-full">
          <span class="m0 muted">
            #{render_money hcb_code.amount_cents_by_event(ProsemirrorService::Renderer.event)}
          </span>
        </footer>
      HTML
    end

  end
end
