class MakeSlugNullableOnReferralLinks < ActiveRecord::Migration[8.0]
  def change
    change_column_null :referral_links, :slug, true
  end
end
