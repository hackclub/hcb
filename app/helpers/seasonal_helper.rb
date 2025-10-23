# frozen_string_literal: true

module SeasonalHelper
  SEASONS = {
    # format:
    # [[start_month, start_day], [end_month, end_day]]

    fall: [[10, 1], [10, 31]],
    winter: [[12, 1], [12, 31]],
  }.freeze

  SEASONS.each_key do |key|
    define_method "#{key}?" do |override_preference = false|
      user = (current_user if self.respond_to? :current_user, true)
      if !override_preference && (user&.seasonal_themes_disabled? || @hide_seasonal_decorations) # rubocop:disable Rails/HelperInstanceVariable
        return false
      end

      today = Date.today
      low = SEASONS[key][0]
      high = SEASONS[key][1]

      today.day.between?(low[1], high[1]) && today.month.between?(low[0], high[0])
    end
  end

  def by_season(default, hash)
    hash.filter { |key, value| key != :override_preference }.each do |key, value|
      return value if send("#{key}?", hash[:override_preference])
    end

    return default
  end

  def current_season(override_preference: false)
    SEASONS.each_key do |key|
      return key if send("#{key}?", override_preference)
    end

    nil
  end
end
