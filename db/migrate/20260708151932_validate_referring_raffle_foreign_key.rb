class ValidateReferringRaffleForeignKey < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :raffles, :raffles
  end
end
