# frozen_string_literal: true

class Event
  class SubOrganizationsExport
    # Excel supports at most 7 levels of row grouping. Deeper descendants are
    # still exported, they just share the deepest collapsible level.
    MAX_OUTLINE_LEVEL = 7

    def initialize(event, descendant_ids:)
      @event = event
      @descendant_ids = descendant_ids
    end

    def xlsx
      io = StringIO.new
      workbook = WriteXLSX.new(io)

      bold = workbook.add_format(bold: 1)

      worksheet = workbook.add_worksheet("Sub-organizations")
      # Syntax: outline_settings(visible, symbols_below, symbols_right, auto_style)
      #
      # `symbols_below: 0` attaches each group's collapse toggle to the parent
      # row above it rather than the default summary row below.
      #
      # `visible` and `auto_style` are inverted: write_xlsx guards them with a
      # bare Ruby truthiness check, and `0` is truthy in Ruby, so any number
      # turns them on. Passing `1` for `visible` writes
      # `showOutlineSymbols="0"` onto <sheetView>, which hides the grouping
      # gutter in Excel (Google Sheets ignores the attribute, which is why the
      # tree looked fine there). `false` is the only value that leaves both
      # attributes out.
      # https://github.com/cxn03651/write_xlsx/blob/v1.12.3/lib/write_xlsx/worksheet.rb#L3618
      worksheet.outline_settings(false, 0, 0, false)
      worksheet.set_column("A:A", 20)
      worksheet.set_column("B:C", 40)
      worksheet.set_column("D:D", 12)
      worksheet.set_column("E:E", 30)

      worksheet.write_row(0, 0, ["ID", "Name", "Slug", "Balance", "Tags"], bold)

      @current_row = 1
      children_of(@event.id).each { |subevent| write_subtree(worksheet, subevent, 0) }

      workbook.close
      io.string
    end

    private

    def write_subtree(worksheet, event, depth)
      tags_for_parent = event.scoped_tags.select { |tag| tag.parent_event_id == event.parent_id }

      # write_string keeps user-provided values (e.g. a name starting with "=")
      # from being interpreted as formulas.
      worksheet.write_string(@current_row, 0, event.public_id)
      worksheet.write_string(@current_row, 1, "#{"    " * depth}#{event.name}")
      worksheet.write_string(@current_row, 2, event.slug)
      worksheet.write_number(@current_row, 3, event.balance_v2_cents / 100.0)
      worksheet.write_string(@current_row, 4, tags_for_parent.map(&:name).join(", "))

      if depth.positive?
        # Syntax: set_row(row, height, format, hidden, level, collapsed)
        worksheet.set_row(@current_row, nil, nil, 0, depth.clamp(0, MAX_OUTLINE_LEVEL))
      end

      @current_row += 1

      children_of(event.id).each { |child| write_subtree(worksheet, child, depth + 1) }
    end

    def children_of(parent_id)
      children_by_parent_id[parent_id] || []
    end

    def children_by_parent_id
      @children_by_parent_id ||= Event.where(id: @descendant_ids)
                                      .includes(:scoped_tags)
                                      .order(:name)
                                      .group_by(&:parent_id)
    end

  end

end
