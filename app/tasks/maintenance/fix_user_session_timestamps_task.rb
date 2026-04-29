# frozen_string_literal: true

module Maintenance
  class FixUserSessionTimestampsTask < MaintenanceTasks::Task
    # Restores expiration_at and signed_out_at on User::Session records
    # corrupted by the bug fixed in #13375. Before that fix,
    # sign_out_of_all_sessions lacked .not_expired and would overwrite
    # timestamps on already-expired sessions. We use PaperTrail to find
    # the correct pre-corruption state for each affected session.
    def collection
      ActiveRecord::Base.connection.execute(<<~SQL).map do |row|
        SELECT DISTINCT ON (item_id) item_id, object
        FROM versions
        WHERE item_type = 'User::Session'
          AND event = 'update'
          AND object_changes ? 'expiration_at'
          AND (object_changes->'expiration_at'->>0)::timestamptz <= created_at
        ORDER BY item_id, created_at ASC
      SQL
        obj = JSON.parse(row["object"])
        {
          session_id: row["item_id"].to_i,
          expiration_at: obj["expiration_at"] && Time.zone.parse(obj["expiration_at"]),
          signed_out_at: obj["signed_out_at"] && Time.zone.parse(obj["signed_out_at"])
        }
      end
    end

    def process(correction)
      User::Session.where(id: correction[:session_id]).update_all(
        expiration_at: correction[:expiration_at],
        signed_out_at: correction[:signed_out_at]
      )
    end
  end
end
