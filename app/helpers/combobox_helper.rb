# frozen_string_literal: true

module ComboboxHelper
  # Renders an async, searchable select driven by `combobox_controller.js`.
  #
  #   combobox_tag :event_id, event_search_admin_index_path, selected: @event
  #
  # `name` is the submitted parameter name and `src` an endpoint returning
  # `[{ value, label, sublabel, disabled }]` JSON — see the controller for the
  # full contract. Options:
  #
  #   selected:    the current choice. A record (its `id` and
  #                `to_combobox_display` are used), or a `{ value:, label: }`
  #                Hash for records keyed on something other than `id`.
  #   class:       classes for the control itself, which owns its width. The
  #                dropdown is sized to match, so this is where `!max-w-full`
  #                and friends belong.
  #   data:        data attributes for the control (e.g. targets of an outer
  #                controller). A `controller:` key is appended to `combobox`.
  #   id:          DOM id for the visible input. Defaults to one derived from
  #                `name`; override where that would collide.
  #
  # Remaining keyword arguments (`placeholder:`, `disabled:`, …) are passed
  # through to the visible input. Note that input is display-only and carries no
  # `name`, so `required:` there would validate the wrong field — enforce
  # presence server-side instead.
  def combobox_tag(name, src, selected: nil, data: {}, **input_options)
    value, display = combobox_selection(selected)
    wrapper_class = input_options.delete(:class)
    input_id = input_options.delete(:id) || name.to_s.gsub(/\W+/, "_").delete_suffix("_")
    listbox_id = "#{input_id}_listbox"

    input = tag.input(**{
      type: "text", id: input_id, role: "combobox",
      class: "combobox__input",
      placeholder: "Select one…", autocomplete: "off",
      aria: { autocomplete: "both", expanded: false, controls: listbox_id },
      data: { combobox_target: "input", action: "input->combobox#onInput focus->combobox#onFocus keydown->combobox#onKeydown blur->combobox#onBlur" }
    }.deep_merge(input_options))

    tag.div class: token_list("combobox", wrapper_class),
            data: { controller: token_list("combobox", data[:controller]),
                    combobox_url_value: src, combobox_selected_value: value,
                    combobox_label_value: display }.merge(data.except(:controller)) do
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

  private

  # Records are keyed on `id`; pass a Hash to key on anything else (the
  # disbursements endpoint, for instance, returns `public_id` values).
  def combobox_selection(selected)
    case selected
    when nil then []
    when Hash then selected.symbolize_keys.values_at(:value, :label)
    else [selected.id, selected.to_combobox_display(admin: admin_signed_in?)]
    end
  end
end
