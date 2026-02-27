module PopoverHelper
  def popovers_enabled?
    current_user && Flipper.enabled?(:hcb_code_popovers_2023_06_16, current_user)
  end

  # Builds the data attributes hash for triggering the shared popover modal.
  #
  # Usage in views:
  #   link_to "Label", href, data: popover_data(title: "...", src: "/path", ...)
  def popover_data(title:, src:, frame_id:, state_url:, external_link: nil, state_title: nil, size: nil)
    {
      turbo_frame: "_top",
      behavior: "modal_trigger",
      modal: "shared_popover",
      popover_title: title,
      popover_src: src,
      popover_frame_id: frame_id,
      popover_state_url: state_url,
      popover_external_link: external_link,
      popover_state_title: state_title,
      popover_size: size
    }.compact
  end

  def hcb_code_popover_data(hcb_code, event: nil, **popover_path_params)
    popover_data(
      title: hcb_code.pretty_title(show_event_name: false, show_amount: true, event: event),
      src: hcb_code.popover_path(**popover_path_params),
      frame_id: hcb_code.public_id,
      state_url: hcb_code_path(hcb_code),
      external_link: url_for(hcb_code)
    )
  end

  def card_grant_popover_data(card_grant, hcb_code:, event: nil, state_title: nil)
    popover_data(
      title: hcb_code.pretty_title(show_event_name: false, show_amount: true, event: event),
      src: spending_card_grant_path(card_grant, params: { frame: true }),
      frame_id: "spending_#{card_grant.public_id}",
      state_url: spending_card_grant_path(card_grant),
      external_link: spending_card_grant_path(card_grant),
      state_title: state_title
    )
  end

  def stripe_card_popover_data(stripe_card)
    popover_data(
      title: stripe_card.initially_activated ? "Card #{stripe_card.last_four}" : "Inactive card",
      src: stripe_card.popover_path,
      frame_id: "stripe_card_#{stripe_card.public_id}",
      state_url: url_for(stripe_card),
      external_link: url_for(stripe_card),
      size: "sm"
    )
  end

  def employee_popover_data(employee)
    popover_data(
      title: "#{employee.user.name}'s payroll",
      src: employee.popover_path,
      frame_id: "employee_#{employee.hashid}",
      state_url: employee_path(employee),
      external_link: employee_path(employee)
    )
  end
end
