class AddAasmStateDocumentDefault < ActiveRecord::Migration[7.0]
  def up
    Document.where(aasm_state: nil).update_all(aasm_state: 'active')
  end
  def down
  end
end
