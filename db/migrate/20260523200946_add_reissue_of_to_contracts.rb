class AddReissueOfToContracts < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :contracts, :reissue_of, index: {algorithm: :concurrently}
  end
end
