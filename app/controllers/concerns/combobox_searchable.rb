# frozen_string_literal: true

module ComboboxSearchable
  # must equal the value of `PAGE_SIZE` in app/javascript/controllers/combobox_controller.js
  PAGE_SIZE = 25

  private

  def combobox_page(relation)
    relation.page(params[:page]).per(PAGE_SIZE)
  end
end
