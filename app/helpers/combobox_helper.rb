# frozen_string_literal: true

module ComboboxHelper
  INPUT_ACTIONS = "input->combobox#onInput focus->combobox#onFocus " \
                  "keydown->combobox#onKeydown blur->combobox#onBlur"
  private_constant :INPUT_ACTIONS

  def combobox_tag(name, src, selected: nil, data: {}, **input_options)
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

  def combobox_display(record)
    record.to_combobox_display(admin: admin_signed_in?)
  end

  private

  def combobox_selection(selected)
    case selected
    when nil then []
    when Hash then selected.symbolize_keys.values_at(:value, :label)
    else [selected.id, combobox_display(selected)]
    end
  end
end
