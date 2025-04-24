import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "text", "menu", "container" ]

  open = false

  connect() {
    document.addEventListener("click", this.handleDocumentClick.bind(this));
  }

  disconnect() {
    document.removeEventListener("click", this.handleDocumentClick.bind(this));
  }

  toggle() {
    this.open = !this.open;
    this.updateMenu();
  }

  change(event) {
    const newType = event.target.value;
    this.updateText(newType);
    this.toggle();
  }

  updateText(value) {
    this.textTarget.innerText = this.textTarget.dataset.template.replaceAll("[VALUE]", value);
  }

  updateMenu() {
    this.menuTarget.style = this.open ? "display: block;" : "display: none;"
  }

  handleDocumentClick(event) {
    if (!this.containerTarget.contains(event.target) && this.open == true) {
      this.toggle();
    }
  }
}
