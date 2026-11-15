# frozen_string_literal: true

class MarkdownScrubber < Rails::HTML::PermitScrubber
  def initialize
    super

    # Following Gitlab's markdown sanitizer
    # https://gitlab.com/gitlab-org/gitlab/-/blob/ad632cbc7a96a1122351198f00623edc2e9ad403/app/assets/javascripts/notebook/cells/markdown.vue#L104-159
    self.tags = %w(a abbr b blockquote br code dd del div dl dt em h1 h2 h3 h4 h5 h6 hr i img ins kbd li ol p pre q rp rt ruby s samp span strike strong sub summary sup table tbody td tfoot th thead tr tt ul var)
    self.attributes = %w(class style href src target alt aria-label)
  end

end
