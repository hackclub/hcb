# frozen_string_literal: true

class CreateEventTagsAndEvents < ActiveRecord::Migration[7.0]
  def up
    create_table :event_tags_events, id: false do |t|
      t.belongs_to :event_tag, null: false, index: true
      t.belongs_to :event, null: false, index: true
      t.index [:event_tag_id, :event_id], unique: true
    end

    # [@garyhtou] These lines were later commented out, after running the
    # migration in production, because they were causing an error.

    # Migrate data from old boolean columns to new EventTag model
    # hack_clubers = EventTag.find_or_initialize_by(name: EventTag::Tags::ORGANIZED_BY_HACK_CLUBBERS).save!(validate: false)
    # teenagers = EventTag.find_or_initialize_by(name: EventTag::Tags::ORGANIZED_BY_TEENAGERS).save!(validate: false)
    #
    # Event.where(organized_by_hack_clubbers: true).find_each do |e|
    #   e.event_tags << hack_clubers
    # end
    #
    # Event.where(organized_by_teenagers: true).find_each do |e|
    #   e.event_tags << teenagers
    # end

  end

  def down
    drop_table :event_tags_events
  end

end
