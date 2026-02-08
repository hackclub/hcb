import { Controller } from "@hotwired/stimulus"

// Prevents double-submission of forms by disabling the submit button
// after the first click and adding a visual loading indicator.
//
// Usage:
//   <form data-controller="submit-once">
//     <button type="submit" data-submit-once-target="button">Send</button>
//   </form>
export default class extends Controller {
  static targets = ["button"]

  submit(event) {
    if (this.submitted) {
      event.preventDefault()
      return
    }

    this.submitted = true

    this.buttonTargets.forEach((button) => {
      button.disabled = true
      button.style.opacity = "0.6"
      button.style.pointerEvents = "none"
    })
  }
}
