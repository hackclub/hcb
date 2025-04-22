import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "button", "select" ]

  connect() {
    this.updateText(this.selectTarget.value);
  }

  change(event) {
    const newType = event.target.value;
    this.updateText(newType);
  }

  updateText(value) {
    this.buttonTarget.innerText = this.buttonTarget.dataset.template.replaceAll("[VALUE]", value);
  }
}
