# frozen_string_literal: true

# == Schema Information
#
# Table name: metrics
#
#  id            :bigint           not null, primary key
#  aasm_state    :string
#  canceled_at   :datetime
#  completed_at  :datetime
#  failed_at     :datetime
#  metric        :jsonb
#  processing_at :datetime
#  subject_type  :string
#  type          :string           not null
#  year          :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  subject_id    :bigint
#
# Indexes
#
#  index_metrics_on_subject                                        (subject_type,subject_id)
#  index_metrics_on_subject_type_and_subject_id_and_type_and_year  (subject_type,subject_id,type,year) UNIQUE
#

class Metric < ApplicationRecord
  after_initialize do
    raise "Cannot directly instantiate a Metric" if self.instance_of? Metric
  end

  belongs_to :subject, polymorphic: true, optional: true # if missing, it's an application-wide metric

  include AASM

  aasm timestamps: true do
    state :queued, initial: true
    state :processing
    state :completed
    state :failed
    state :canceled

    event :mark_processing do
      transitions to: :processing
    end

    event :mark_completed do
      transitions from: :processing, to: :completed
    end

    event :mark_failed do
      transitions from: :processing, to: :failed
    end

    event :mark_canceled do
      transitions from: :queued, to: :canceled
    end
  end

  def populate!
    mark_processing!
    begin
      self.metric = calculate
      mark_completed!
    rescue => e
      Rails.error.report e
      mark_failed!
    end

    self
  end

  def calculate
    raise UnimplementedError
  end

  def geocode(location)
    loc_array = location.split(" - ")
    zip = loc_array.last
    unless zip == "000000"
      geocode = Geocoder.search(location)[0]
      if geocode&.data.present? && (context = geocode.data["context"]).present?
        place = context.find { |c| c["id"]&.start_with?("place") }&.[]("text")
        region = context.find { |c| c["id"]&.start_with?("region") }&.[]("text")
        country = context.find { |c| c["id"]&.start_with?("country") }&.[]("short_code")&.upcase

        if place.present? && region.present?
          return [region, place].compact.join(" - ")
        else
          return [country, region, place].compact.join(" - ")
        end
      elsif geocode&.data.present? && (place_name = geocode.data["matching_place_name"]).present?
        return place_name
      else
        return loc_array[0, loc_array.length - 1].join(" - ")
      end
    end
    return loc_array[0, loc_array.length - 1].join(" - ")
  end

  def self.queue_for_later_from(subject)
    metric = self.order(completed_at: :desc, updated_at: :desc).find_or_create_by!(subject:, year: Metric.year)

    Metric::PopulateJob.perform_later(metric)
  end

  def self.from(subject)
    metric = self.order(completed_at: :desc, updated_at: :desc).find_or_initialize_by(subject:, year: Metric.year)

    return metric if metric.persisted? && metric.completed?

    metric.populate!

    metric
  end

  def self.year
    2025
  end

end
