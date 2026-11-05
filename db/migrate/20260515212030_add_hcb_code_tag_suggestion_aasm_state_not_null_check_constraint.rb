class AddHcbCodeTagSuggestionAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :hcb_code_tag_suggestions, "aasm_state IS NOT NULL", name: "hcb_code_tag_suggestions_aasm_state_null", validate: false
  end
end
