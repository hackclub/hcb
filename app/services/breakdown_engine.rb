# frozen_string_literal: true

module BreakdownEngine
  TIMEFRAMES = {
    "Past year"  => 1.year,
    "Past month" => 1.month
  }.freeze


  def self.date_range(timeframe)
    if TIMEFRAMES.key?(timeframe)
      [TIMEFRAMES[timeframe].ago, Time.now]
    elsif timeframe.to_s.match?(/\A\d{4}\z/)
      year = Time.zone.local(timeframe.to_i)
      [year.beginning_of_year, year.end_of_year]
    else
      [nil, Time.now]
    end
  end

  def self.timeframes_for(event)
    rolling = TIMEFRAMES.select { |_, duration| event.created_at < duration.ago }.keys

    years = event.canonical_transactions
                 .group(Arel.sql("EXTRACT(YEAR FROM canonical_transactions.date)"))
                 .having("COUNT(*) >= ?", 10)
                 .count
                 .keys
                 .map { |year| year.to_i.to_s }
                 .sort
                 .reverse

    ["All time", *rolling, *years]
  end

end
