class UpdateFunctionHcbCodeTypeToVersion2 < ActiveRecord::Migration[8.0]
  def change
    update_function :hcb_code_type, version: 2, revert_to_version: 1
  end
end
