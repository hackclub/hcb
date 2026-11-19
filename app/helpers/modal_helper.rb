# frozen_string_literal: true

module ModalHelper
  # A native <dialog>, opened by any element with `data-modal="<id>"`. See dev-docs/guides/modals.md.
  def modal(title = nil, id:, size: nil, external_link: nil, open: false, **attributes, &)
    attributes[:class] = token_list("modal modal--scroll bg-snow", { "modal--#{size}" => size }, attributes[:class])
    # It's opened non-modally (app/javascript/modal.js), so this is what tells screen readers the page behind is out of reach
    attributes[:aria] = { modal: true, **({ labelledby: "#{id}_title" } if title).to_h, **attributes[:aria].to_h }
    attributes[:data] = {
      **attributes[:data].to_h,
      controller: token_list(attributes.dig(:data, :controller), "open-modal": open).presence,
      turbo_temporary: (true if open) # a one-off, so the page Back restores leaves it out
    }

    # Opened with `show()` (app/javascript/modal.js), which would otherwise ignore close requests like Android's back gesture
    tag.dialog(id:, closedby: "closerequest", **attributes) do
      safe_join [(modal_header(title, id: "#{id}_title", external_link:) if title), capture(&)]
    end
  end

  def modal_header(text, id: nil, external_link: nil)
    tag.header class: "pb2" do
      modal_close +
        (external_link ? modal_external_link(external_link) : "") +
        tag.h2(modal_title(text), id:, class: "h1 mt0 mb0 pb0 border-none")
    end
  end

  # The same for every modal, so it's built once for pages with hundreds of them
  def modal_close
    @modal_close ||= tag.button inline_icon("view-close", size: 28), type: "button", class: "pop modal__close muted", aria: { label: "Close" }, data: { modal_close: true }
  end

  def modal_external_link(external_link)
    pop_icon_to "external", sanitize(external_link), target: "_blank", class: "modal__external muted", data: { controller: "standalone-link" }
  end

  private

  # Titles repeat down a page (a "Select receipt" per transaction), so each is sanitized once
  def modal_title(text)
    (@modal_titles ||= {})[text] ||= sanitize(text)
  end
end
