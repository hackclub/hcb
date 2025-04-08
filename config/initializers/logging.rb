# https://docs.appsignal.com/logging/integrations/ruby.html#rails-logger

appsignal_logger = Appsignal::Logger.new("rails")
appsignal_logger.broadcast_to(Rails.logger)
Rails.logger = ActiveSupport::TaggedLogging.new(appsignal_logger)
