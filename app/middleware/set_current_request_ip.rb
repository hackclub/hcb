# frozen_string_literal: true

class SetCurrentRequestIp
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    Current.request_ip = request.remote_ip
    @app.call(env)
  end
end

