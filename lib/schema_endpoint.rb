# frozen_string_literal: true

# A very simple Rack app that outputs the current database schema in the same
# format as `db/schema.rb` so we can resolve differences between development
# and production environments.
class SchemaEndpoint
  include Singleton

  STREAM_SCHEMA = ->(io) {
    begin
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection_pool, io)
    ensure
      io.close
    end
  }

  RESPONSE_HEADERS = {
    "Content-Type" => "text/plain; charset=utf-8",
  }.freeze

  def call(env)
    request = Rack::Request.new(env)

    unless request.get?
      return [404, {}, ["Not found"]]
    end

    # Stream the response if the server supports it
    # https://github.com/rack/rack/blob/main/SPEC.rdoc#hijacking-
    if env["rack.hijack?"]
      [200, RESPONSE_HEADERS.merge("rack.hijack" => STREAM_SCHEMA), []]
    else
      schema = StringIO.new
      STREAM_SCHEMA.call(schema)
      [200, RESPONSE_HEADERS, [schema.string]]
    end
  end

end
