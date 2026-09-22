# frozen_string_literal: true

# Shared plumbing for the search endpoints backing `ComboboxHelper#combobox_tag`.
# The controller builds and orders the relation; this slices it to the page the
# Stimulus controller asked for.
module ComboboxSearchable
  # must equal the value of `PAGE_SIZE` in app/javascript/controllers/combobox_controller.js
  PAGE_SIZE = 25

  private

  # The combobox pages as the user scrolls, and treats a short page as the last
  # one, so this must return a full page whenever more rows exist.
  def combobox_page(relation)
    relation.page(params[:page]).per(PAGE_SIZE)
  end
end
