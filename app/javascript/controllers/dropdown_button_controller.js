import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "text", "menu" ]

  open = false

  connect() {
    this.updateText(this.selectTarget.value);
  }

  toggle() {
    this.open = !this.open;
    this.updateMenu();
  }

  change(event) {
    const newType = event.target.value;
    this.updateText(newType);
  }

  updateText(value) {
    this.textTarget.innerText = this.textTarget.dataset.template.replaceAll("[VALUE]", value);
  }

  updateMenu() {
    this.menuTarget.style = this.open ? "display: block;" : "display: none;"
  }
}
