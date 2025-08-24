# frozen_string_literal: true

ActiveJob::TrafficControl.client = Redis.new
