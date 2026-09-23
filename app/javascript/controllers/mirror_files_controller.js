import { Controller } from '@hotwired/stimulus'

// Copies a file input's selection onto another input, so a styled picker and the
// field the form actually submits stay in sync. Attach to the picker itself:
//
//   data: { controller: "mirror-files", action: "input->mirror-files#mirror",
//           mirror_files_to_value: "event_logo" }
export default class extends Controller {
  static values = { to: String }

  mirror({ target } = {}) {
    const source = target instanceof HTMLInputElement ? target : this.element
    const destination = document.getElementById(this.toValue)
    if (destination && source.files) destination.files = source.files
  }
}
