# frozen_string_literal: true

module SearchService
  class Parser
    include SearchService::Shared

    def initialize(input)
      @input = input
    end

    def run

      # this line parses the query into a useable format

      parsed = @input&.scan(/(?:[^@]+|@[^@]+)/)&.map { |str|
        type = str.match(/@(\w+)/)&.[](1)
        conditions = str.scan(/\[([^\]]+)\]/)
        subtype = str.match(/@#{type}:(\w+)/)&.[](1)
        {
          "types"      => [shorthands[type] || type],
          "subtype"    => subtype_shorthands[subtype] || subtype,
          "conditions" => conditions.select { |condition| condition[0].split.length >= 3 }.map { |condition|
            {
              "property": condition[0].split[0],
              "operator": condition[0].split[1],
              "value": condition[0].split[2..].join(" ")
            }
          },
          "query"      => subtype ? str.gsub(/@\w+:\w+\s*|\[.*?\]/, "").strip : str.gsub(/@\w+\s*|\[.*?\]/, "").strip
        }
      }

      # the following preforms a series of validations on the query object
      # that we've generated.

      previous = nil

      parsed.each do |item|
        raise Errors::ValidationError, "#{item['types'][0]} is not a valid type." if item["types"][0] && !types[item["types"][0]]

        if previous && !types[previous]["children"].include?(item["types"][0])
          raise Errors::ValidationError, "#{item['type']} is not a valid child of #{previous}."
        end
        if item["subtype"] && !types[item["types"][0]]["subtypes"].keys.include?(item["subtype"])
          raise Errors::ValidationError, "#{item["subtype"]} is not a valid subtype of #{item["types"][0]}."
        end

        item["conditions"]&.each do |condition|
          unless types[item["types"][0]]["properties"].include?(condition[:property])
            raise Errors::ValidationError, "#{condition[:property]} is not a valid property for #{item['types'][0]}."
          end
          unless [">", "<", "=", "<=", ">="].include?(condition[:operator])
            raise Errors::ValidationError, "#{condition[:operator]} is not a valid comparison operator."
          end

          case condition[:property]
          when "date"
            raise Errors::ValidationError, "#{condition[:value]} is not a valid date." unless Chronic.parse(condition[:value], context: :past)
          when "amount"
            raise Errors::ValidationError, "#{condition[:operator]} is not a valid comparison operator." unless convert_to_float(condition[:value])
          end
        end

        previous = item["types"][0]
      end

      # this guesses the type if I user doesn't specify

      if parsed[0]["types"][0].nil? && parsed.length > 1
        child_type = parsed[1]["type"]
        parsed[0]["types"] = []
        types.each do |key, value|
          if value["children"].include?(child_type)
            parsed[0]["types"] << key
          end
        end
      elsif parsed[0]["types"][0].nil?
        parsed[0]["types"] = ["organization", "user", "card", "transaction"]
      end

      return parsed
    end


  end
end
