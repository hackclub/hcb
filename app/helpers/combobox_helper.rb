# frozen_string_literal: true

module ComboboxHelper
  INPUT_ACTIONS = "input->combobox#onInput focus->combobox#onFocus " \
                  "keydown->combobox#onKeydown blur->combobox#onBlur"
  private_constant :INPUT_ACTIONS

  # Renders an async, searchable select driven by `combobox_controller.js`.
  #
  #   combobox_tag :event_id, event_search_admin_index_path, selected: @event
  #
  # `name` is the submitted parameter name; `src` an endpoint returning
  # `[{ value, label, sublabel, disabled }]` JSON, whose full contract lives
  # with the Stimulus controller.
  #
  #   selected:  the current choice: a record, or a `{ value:, label: }` Hash
  #              for records keyed on something other than `id`.
  #   class:     classes for the control, which owns its width. The dropdown is
  #              sized to match it, so `!max-w-full` and friends belong here.
  #   id:        DOM id for the visible input, defaulting to one derived from
  #              `name`. Override it where that would collide.
  #   data:      data attributes for the control, e.g. an outer controller's
  #              targets. A `controller:` key is appended to `combobox`.
  #
  # Anything else (`placeholder:`, `disabled:`, …) goes to the visible input.
  # That input is display-only and has no `name`, so `required:` on it would
  # validate the wrong field; enforce presence server-side instead.
  def combobox_tag(name, src, selected: nil, data: {}, **input_options)
    # These two address the wrapper and the input respectively; everything left
    # in `input_options` afterwards belongs to the input.
    wrapper_class = input_options.delete(:class)
    input_id = input_options.delete(:id) || name.to_s.gsub(/\W+/, "_").delete_suffix("_")

    listbox_id = "#{input_id}_listbox"
    value, label = combobox_selection(selected)

    input = tag.input(
      type: "text", id: input_id, role: "combobox", class: "combobox__input",
      placeholder: "Select one…", autocomplete: "off",
      aria: { autocomplete: "both", expanded: false, controls: listbox_id },
      data: { combobox_target: "input", action: INPUT_ACTIONS },
      **input_options
    )

    wrapper_data = {
      controller: token_list("combobox", data[:controller]),
      combobox_url_value: src,
      combobox_selected_value: value,
      combobox_label_value: label,
      **data.except(:controller)
    }

    tag.div class: token_list("combobox", wrapper_class), data: wrapper_data do
      safe_join [
        tag.div(input + tag.div(class: "combobox__handle"), class: "combobox__field"),
        hidden_field_tag(name, value, id: nil, data: { combobox_target: "hidden" }),
        tag.ul(nil, role: "listbox", id: listbox_id, class: "combobox__listbox",
                    aria: { label: "Suggestions" }, hidden: true,
                    data: { combobox_target: "listbox", action: "scroll->combobox#onScroll" }),
        tag.div(nil, class: "combobox__announcer", role: "status",
                     aria: { live: "polite" }, data: { combobox_target: "status" })
      ]
    end
  end

  # The single place that decides whether a label carries admin detail. Both the
  # preselected value rendered above and the rows returned by the search
  # endpoints go through here, so the two cannot disagree — when they did, the
  # field silently changed its text as soon as the user re-picked the value it
  # already had.
  def combobox_display(record)
    record.to_combobox_display(admin: admin_signed_in?)
  end

  private

  # Records are keyed on `id`; pass a Hash to key on anything else (the
  # disbursements endpoint, for instance, returns `public_id` values).
  def combobox_selection(selected)
    case selected
    when nil then []
    when Hash then selected.symbolize_keys.values_at(:value, :label)
    else [selected.id, combobox_display(selected)]
    end
  end
end
