# frozen_string_literal: true

module ComboboxHelper
  DEFAULT_COMBOBOX_PLACEHOLDER = "Select one…"

  COMBOBOX_INPUT_ACTIONS = %w[
    input->combobox#onInput
    focus->combobox#onFocus
    keydown->combobox#onKeydown
    blur->combobox#onBlur
  ].join(" ").freeze

  def combobox_tag(name, src, selected: nil, wrapper_class: nil, data: {}, **input_options)
    value, display = combobox_selection(selected)
    input_id = input_options.delete(:id) || combobox_id_for(name)
    listbox_id = "#{input_id}_listbox"

    field = tag.div class: "combobox__field" do
      tag.input(**{
        type: "text",
        id: input_id,
        role: "combobox",
        class: token_list("combobox__input", input_options.delete(:class)),
        placeholder: DEFAULT_COMBOBOX_PLACEHOLDER,
        autocomplete: "off",
        aria: { autocomplete: "both", expanded: false, controls: listbox_id },
        data: { combobox_target: "input", action: COMBOBOX_INPUT_ACTIONS }
      }.deep_merge(input_options)) + tag.div(class: "combobox__handle")
    end

    tag.div class: token_list("combobox", wrapper_class),
            data: {
              controller: token_list("combobox", data[:controller]),
              combobox_url_value: src,
              combobox_selected_value: value,
              combobox_label_value: display
            }.merge(data.except(:controller)) do
      safe_join [
        field,
        hidden_field_tag(name, value, id: nil, data: { combobox_target: "hidden" }),
        tag.ul(nil, role: "listbox", id: listbox_id, class: "combobox__listbox",
                    hidden: true, data: { combobox_target: "listbox" })
      ]
    end
  end

  private

  def combobox_selection(selected)
    case selected
    when nil then [nil, nil]
    when Hash then [selected[:value], selected[:label]]
    else [selected.id, selected.to_combobox_display]
    end
  end

  def combobox_id_for(name)
    name.to_s.gsub(/\W+/, "_").delete_suffix("_")
  end
end
