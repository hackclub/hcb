# frozen_string_literal: true

# Rails' default schema format does not include the frozen string pragma (which
# we would like it to have), so we have to constantly make sure to add it back
# when we add migrations.
#
# This module (which gets prepended to `ActiveRecord::SchemaDumper`) overrides
# the `dump` method to write the comment at the beginning of the stream before
# letting the rest of the code proceed.
module PrependFrozenStringLiteral
  # https://github.com/rails/rails/blob/ac18a8b9d365c9a0698d577e48c3e76ea6a764b9/activerecord/lib/active_record/schema_dumper.rb#L60-L68
  def dump(stream)
    stream.print("# frozen_string_literal: true\n\n")
    super
  end
end

ActiveRecord::SchemaDumper.prepend(PrependFrozenStringLiteral)
