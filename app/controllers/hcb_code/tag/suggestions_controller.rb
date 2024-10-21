# frozen_string_literal: true

class HcbCode
  module Tag
    class SuggestionsController < ApplicationController
      def accept
        suggestion = HcbCode::Tag::Suggestion.find(params[:suggestion_id])
        authorize suggestion
        suggestion.mark_accepted!
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.remove("tag_suggestion_#{suggestion.id}")
          end
          format.any { redirect_back fallback_location: @event }
        end
      end

      def reject
        suggestion = HcbCode::Tag::Suggestion.find(params[:suggestion_id])
        authorize suggestion
        suggestion.mark_rejected!
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.remove("tag_suggestion_#{suggestion.id}")
          end
          format.any { redirect_back fallback_location: @event }
        end
      end


    end
  end

end
