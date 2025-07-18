class CreateAnnouncementBlocks < ActiveRecord::Migration[7.2]
  def change
    create_table :announcement_blocks do |t|
      t.text :rendered_html
      t.text :rendered_email_html
      t.jsonb :parameters
      t.references :announcement, foreign_key: true, null: false
      t.string :type, null: false

      t.timestamps
    end
  end
end
