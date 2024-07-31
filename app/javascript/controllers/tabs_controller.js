// app/javascript/controllers/tabs_controller.js
import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="tabs"
export default class extends Controller {
  static targets = ['btn', 'tab']
  static values = { defaultTab: String }

  connect() {
    this.tabTargets.forEach(x => (x.hidden = true)) // hide all tabs by default
    // OPEN DEFAULT TAB
    let selectedBtn = this.btnTargets.find(
      element => element.id === this.defaultTabValue
    )
    let selectedTab = this.tabTargets.find(
      element => element.id === this.defaultTabValue
    )
    if (selectedTab && selectedBtn) {
      selectedTab.hidden = false
      selectedBtn.classList.add('active')
    }
  }

  select(event) {
    // find tab with same id as clicked btn
    let selectedTab = this.tabTargets.find(
      element => element.id === event.currentTarget.id
    )
    if (selectedTab.hidden) {
      // CLOSE CURRENT TAB
      this.tabTargets.forEach(x => (x.hidden = true)) // hide all tabs
      this.btnTargets.forEach(x => x.classList.remove('active')) // deactive all btns
      selectedTab.hidden = false // show current tab
      event.currentTarget.classList.add('active') // active current btn
    }
    // No need to add anything else since we don't want to toggle the tab visibility
  }
}
