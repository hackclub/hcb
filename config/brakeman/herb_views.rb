# frozen_string_literal: true

# Brakeman only scans `.erb`, `.haml` and `.slim` views. Our `.html.herb` views
# (rendered by ReActionView) are HTML+ERB too, so this teaches Brakeman to find
# them and parse them as ERB, keeping them under the same XSS checks as every
# other view.
#
# Brakeman has no setting for extra template extensions. It does load every
# file passed with `--add-checks-path` before it scans the app, which is the
# only hook that runs early enough. CI and bin/brakeman pass this directory.
module Brakeman
  module HerbViews
    EXTENSION = ".html.herb"

    module AppTree
      def template_paths
        @template_paths ||= super + find_paths(".", "*#{EXTENSION}")
      end
    end

    module TemplateParser
      # Mirrors Brakeman::TemplateParser#parse_template's ERB branch, which
      # picks the parser from the file extension and has no case for `.herb`.
      def parse_template(path, text)
        return super unless path.relative.end_with?(EXTENSION)

        Brakeman.debug "Parsing #{path}"

        begin
          type = erubis? ? :erubis : :erb
          src = parse_erb(path, text)

          if src && (ast = @file_parser.parse_ruby(src, path))
            @file_parser.file_list << Brakeman::TemplateParser::TemplateFile.new(path, ast, template_path_to_name(path), type)
          end
        rescue Racc::ParseError => e
          tracker.error e, "Could not parse #{path}"
        rescue StandardError, LoadError => e
          tracker.error e.exception(e.message + "\nWhile processing #{path}"), e.backtrace
        end

        nil
      end
    end
  end

  AppTree.prepend(HerbViews::AppTree)
  TemplateParser.prepend(HerbViews::TemplateParser)
end
