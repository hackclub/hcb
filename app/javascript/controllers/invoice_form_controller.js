import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ["sponsorCollapsible", "sponsorPreview", "sponsorPreviewName", "sponsorPreviewEmail"]

  connect() {
  }
}
