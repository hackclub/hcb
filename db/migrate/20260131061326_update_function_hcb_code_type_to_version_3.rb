class UpdateFunctionHcbCodeTypeToVersion3 < ActiveRecord::Migration[8.0]
  def change
    update_function :hcb_code_type, version: 3, revert_to_version: 2
  end
end
