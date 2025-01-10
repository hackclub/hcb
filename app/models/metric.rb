# frozen_string_literal: true

# == Schema Information
#
# Table name: metrics
#
#  id           :bigint           not null, primary key
#  metric       :jsonb
#  subject_type :string
#  type         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  subject_id   :bigint
#
# Indexes
#
#  index_metrics_on_subject                               (subject_type,subject_id)
#  index_metrics_on_subject_type_and_subject_id_and_type  (subject_type,subject_id,type) UNIQUE
#

class Metric < ApplicationRecord
  after_initialize do
    raise "Cannot directly instantiate a Metric" if self.instance_of? Metric
  end

  before_create :populate
  belongs_to :subject, polymorphic: true, optional: true # if missing, it's an application-wide metric

  def populate
    self.metric = calculate
    touch if persisted? # Shows that the metric is update to date; even if value hasn't changed
  end

  def calculate
    raise UnimplementedError
  end

  def geocode(location)
    loc_array = location.split(" - ")
    zip = loc_array.last
    unless zip == "000000"
      geocode = Geocoder.search(location)[0]
      if geocode.present? && (address = Geocoder.search(location)[0]&.data&.[]("address"))
        if address["town"]
          return "#{loc_array[0, loc_array.length - 1].join(" - ")} - #{address["town"]}"
        elsif address["city"]
          return "#{loc_array[0, loc_array.length - 1].join(" - ")} - #{address["city"]}"
        elsif address["county"]
          return "#{loc_array[0, loc_array.length - 1].join(" - ")} - #{address["county"]}"
        end

      end
    end
    return loc_array[0, loc_array.length - 1].join(" - ")
  end

  def self.from(subject, repopulate: false)
    metric = self.where(subject:).order(updated_at: :desc).first_or_initialize(subject:)

    # If creating, save and return the new record
    if metric.new_record?
      unless metric.save
        Airbrake.notify("Failed to save metric #{metric.inspect}")
        return nil
      end
      return metric
    end

    if repopulate
      metric.populate
      metric.updated_at = Time.now # force touch even if no changes
      unless metric.save
        Airbrake.notify("Failed to save metric #{metric.inspect}")
        metric.reload
      end
    end

    metric
  end

end
