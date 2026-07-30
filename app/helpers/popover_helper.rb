# frozen_string_literal: true

module PopoverHelper
  def popovers_enabled?
    current_user && Flipper.enabled?(:hcb_code_popovers_2023_06_16, current_user)
  end

  # Builds the data attributes hash for triggering the shared popover modal.
  #
  # Usage in views:
  #   link_to "Label", href, data: popover_data(title: "...", src: "/path", ...)
  def popover_data(title:, src:, frame_id:, state_url:, external_link: nil, state_title: nil, size: nil, subtitle: nil)
    {
      turbo_frame: "_top",
      behavior: "modal_trigger",
      modal: "shared_popover",
      popover_title: title,
      popover_subtitle: subtitle,
      popover_src: src,
      popover_frame_id: frame_id,
      popover_state_url: state_url,
      popover_external_link: external_link,
      popover_state_title: state_title,
      popover_size: size
    }.compact
  end

  private :popover_data

  def hcb_code_popover_data(hcb_code, event: nil, **popover_path_params)
    popover_data(
      title: hcb_code.pretty_title(show_event_name: false, show_amount: true, event: event),
      src: hcb_code.popover_path(**popover_path_params),
      frame_id: hcb_code.public_id,
      state_url: hcb_code_path(hcb_code),
      external_link: url_for(hcb_code)
    )
  end

  def ledger_item_popover_data(item)
    popover_data(
      title: item.hcb_code.pretty_title(show_event_name: false, show_amount: true),
      src: item.hcb_code.popover_path,
      frame_id: item.hcb_code.public_id,
      state_url: ledger_item_path(item),
      external_link: ledger_item_path(item)
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

  def contractor_popover_data(contractor)
    path = event_payroll_position_path(event_id: contractor.event.slug, id: contractor)
    popover_data(
      title: "#{contractor.payee.display_name}'s contract",
      src: event_payroll_position_path(event_id: contractor.event.slug, id: contractor, frame: true),
      frame_id: "contractor_#{contractor.id}",
      state_url: path,
      external_link: path
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

  def payment_popover_data(payment)
    popover_data(
      title: "Payment to #{payment.payee.display_name}",
      src: payment.popover_path,
      frame_id: "payment_#{payment.id}",
      state_url: payment_path(payment),
      external_link: payment_path(payment)
    )
  end

  # The admin "Process" screens. Each one renders itself as a bare turbo frame
  # when requested inside the popover (see `render(layout: !turbo_frame_request?)`),
  # and still works as a full page — which is what the popover's pop-out link
  # goes to.
  ADMIN_PROCESS_LABELS = {
    "AchTransfer"    => "ACH transfer",
    "Wire"           => "Wire",
    "WiseTransfer"   => "Wise transfer",
    "PaypalTransfer" => "PayPal transfer",
    "IncreaseCheck"  => "Check",
    "Disbursement"   => "Transfer",
    "Invoice"        => "Invoice",
  }.freeze
  private_constant :ADMIN_PROCESS_LABELS

  def admin_process_popover_data(transfer)
    return {} unless admin_popovers_enabled?

    label = ADMIN_PROCESS_LABELS[transfer.class.name]
    return {} if label.nil?

    path = admin_process_path(transfer)

    popover_data(
      title: "#{label} ##{transfer.id} · #{admin_process_amount(transfer)}",
      subtitle: admin_popover_subtitle(transfer),
      src: path,
      frame_id: admin_process_frame_id(transfer),
      state_url: path,
      external_link: path,
      size: "lg"
    )
  end

  # Wires and Wise transfers carry their own currency; everything else is USD.
  # Mirrors how the index tables format these amounts.
  def admin_process_amount(record)
    case record
    when ::Wire, ::WiseTransfer
      Money.from_cents(record.amount_cents, record.currency).format
    when ::Invoice
      render_money(record.item_amount)
    else
      render_money(record.amount)
    end
  end

  # Also used by the process views themselves, so the frame they render always
  # matches the one the popover creates for it.
  def admin_process_frame_id(transfer)
    "#{transfer.class.name.underscore}_process_#{transfer.id}"
  end

  def admin_process_path(transfer)
    case transfer
    when ::AchTransfer then ach_start_approval_admin_path(transfer)
    when ::Wire then wire_process_admin_path(transfer)
    when ::WiseTransfer then wise_transfer_process_admin_path(transfer)
    when ::PaypalTransfer then paypal_transfer_process_admin_path(transfer)
    when ::IncreaseCheck then increase_check_process_admin_path(transfer)
    when ::Disbursement then disbursement_process_admin_path(transfer)
    when ::Invoice then invoice_process_admin_path(transfer)
    end
  end

  def legal_entity_popover_data(legal_entity)
    popover_data(
      title: "Payment information for #{legal_entity.name.presence || legal_entity.display_name}",
      src: legal_entity_path(legal_entity, frame: true),
      frame_id: "legal_entity_#{legal_entity.hashid}",
      state_url: legal_entity_path(legal_entity),
      external_link: legal_entity_path(legal_entity)
    )
  end

  # Admin pages are only reachable by admins, so popovers are always available
  # there — no feature flag needed.
  def admin_popovers_enabled?
    current_user&.admin?
  end

  # Returns the popover data attributes for a record, or an empty hash when the
  # record can't be shown in a popover. Designed to be spread into `link_to` /
  # `pop_icon_to` calls in admin views:
  #
  #   link_to ct.memo, transaction_path(ct), data: admin_popover_data_for(ct)
  def admin_popover_data_for(record)
    return {} unless admin_popovers_enabled? && record

    data =
      case record
      when ::StripeCard then stripe_card_popover_data(record)
      when ::Employee then employee_popover_data(record)
      when ::Payment then payment_popover_data(record)
      when ::Ledger::Item then record.hcb_code.present? ? ledger_item_popover_data(record) : {}
      when ::LegalEntity then legal_entity_popover_data(record)
      else
        hcb_code = record.is_a?(::HcbCode) ? record : record.try(:local_hcb_code)
        hcb_code.present? ? hcb_code_popover_data(hcb_code) : {}
      end

    return data if data.empty?

    data.merge(popover_subtitle: admin_popover_subtitle(record)).compact
  end

  # Admin tables span every organization, so name it above the popover's title.
  # The user-facing titles leave the org out on purpose — you already know which
  # org you're looking at — and appending it there would just wrap.
  def admin_popover_subtitle(record)
    event = record.try(:event)
    return if event&.name.blank?

    event.name
  end
end
