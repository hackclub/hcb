import $ from 'jquery'
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect() {
    this.collapseAllForCache = this.collapseAllForCache.bind(this)

    this.rowPanels().each((_, panel) => {
      const open = panel.dataset.open === 'true'
      $(panel).toggle(open)
      this.actionsForPanel(panel)?.classList.toggle('is-editing', open)
    })

    document.addEventListener('turbo:before-cache', this.collapseAllForCache)
  }

  disconnect() {
    document.removeEventListener('turbo:before-cache', this.collapseAllForCache)
  }

  editRow(event) {
    event.preventDefault()
    const row = event.currentTarget.closest('[data-payout-methods-row]')
    this.closeAll()
    $(row.querySelector('[data-payout-methods-panel]')).slideDown(200)
    row.querySelector('[data-pm-actions]').classList.add('is-editing')
  }

  cancelRow(event) {
    event.preventDefault()
    const row = event.currentTarget.closest('[data-payout-methods-row]')
    $(row.querySelector('[data-payout-methods-panel]')).slideUp(200)
    row.querySelector('[data-pm-actions]').classList.remove('is-editing')
  }

  saveRow(event) {
    event.preventDefault()
    const row = event.currentTarget.closest('[data-payout-methods-row]')
    const form = row.querySelector('[data-payout-methods-panel] form')
    if (!form) return
    form.requestSubmit()
  }

  closeAll() {
    this.rowPanels().slideUp(200)
    this.element
      .querySelectorAll('[data-pm-actions]')
      .forEach(a => a.classList.remove('is-editing'))
  }

  collapseAllForCache() {
    this.rowPanels().each((_, el) => {
      $(el).hide()
      el.dataset.open = 'false'
    })
    this.element
      .querySelectorAll('[data-pm-actions]')
      .forEach(a => a.classList.remove('is-editing'))
  }

  rowPanels() {
    return $(this.element).find('[data-payout-methods-panel]')
  }

  actionsForPanel(panel) {
    return panel
      .closest('[data-payout-methods-row]')
      ?.querySelector('[data-pm-actions]')
  }
}
