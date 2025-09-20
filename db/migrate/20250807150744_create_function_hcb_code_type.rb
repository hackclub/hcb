class CreateFunctionHcbCodeType < ActiveRecord::Migration[7.2]
  def change
    create_function :hcb_code_type
  end
end
