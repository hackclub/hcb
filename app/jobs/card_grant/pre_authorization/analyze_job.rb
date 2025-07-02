class CardGrant
  class PreAuthorization
    class AnalyzeJob < ApplicationJob
      def perform(pre_authorization:)
        pre_authorization.analyze!
      end

    end

  end

end
