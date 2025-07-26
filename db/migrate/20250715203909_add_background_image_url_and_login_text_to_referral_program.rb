class AddBackgroundImageUrlAndLoginTextToReferralProgram < ActiveRecord::Migration[7.2]
  def change
    add_column :referral_programs, :background_image_url, :string
    add_column :referral_programs, :login_header_text, :string
    add_column :referral_programs, :login_body_text, :text
    add_column :referral_programs, :login_text_color, :string
  end
end
