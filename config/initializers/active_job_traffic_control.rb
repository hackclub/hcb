# frozen_string_literal: true

ActiveJob::TrafficControl.client = if Rails.env.production?
                                     Redis.new
                                   else
                                     Dalli::Client.new
                                   end
