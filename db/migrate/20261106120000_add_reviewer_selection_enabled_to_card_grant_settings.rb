# frozen_string_literal: true

class AddReviewerSelectionEnabledToCardGrantSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :card_grant_settings, :reviewer_selection_enabled, :boolean, default: false, null: false
  end

end
