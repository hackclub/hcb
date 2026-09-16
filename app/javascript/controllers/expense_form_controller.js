import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'field',
    'button',
    'form',
    'move',
    'memo',
    'memoField',
    'card',
    'lightbox',
    'amountField',
    'fitFeesButton',
    'fitFeesStatus',
  ]
  static values = {
    enabled: { type: Boolean, default: false },
    locked: { type: Boolean, default: false },
    memo: { type: String, default: 'Untitled Expense' },
  }

  connect() {
    for (const field of this.fieldTargets) {
      if (field.nodeName == 'SELECT') {
        field.disabled = !this.enabledValue
      } else {
        field.readOnly = !this.enabledValue
        field.addEventListener('dblclick', () => this.edit())
        this.#addTooltip(field, 'Double-click to edit...')
      }

      document.addEventListener('keydown', e => {
        if (e.key === 'Escape' && this.enabledValue) {
          this.formTarget.reset()
          this.close()
        }
      })
    }

    // we don't render the button if the report is reimbursed
    if (this.hasButtonTarget) {
      this.buttonTarget.addEventListener('click', e => {
        e.preventDefault()
        if (this.enabledValue) {
          this.formTarget.requestSubmit()
        } else {
          this.edit(e)
        }
      })
    }

    this.#buttons()
    this.#label()
    this.#memo()
    this.#memoInput()
    this.#card()
    this.#move()
    this.#lightbox()
  }

  close(e) {
    if (this.lockedValue) return
    this.enabledValue = false

    this.#buttons()
    this.#label()
    this.#memo()
    this.#card()
    this.#move()
    this.#lightbox()

    for (const field of this.fieldTargets) {
      if (field.nodeName == 'SELECT') {
        field.disabled = true
      } else {
        field.readOnly = true
        this.#addTooltip(field, 'Double-click to edit...')
      }
    }

    if (e) {
      e.target?.focus()
    }
  }

  edit(e) {
    if (this.enabledValue || this.lockedValue) return
    this.enabledValue = true

    this.#memo()
    this.#buttons()
    this.#label()
    this.#card()
    this.#move()
    this.#lightbox()

    for (const field of this.fieldTargets) {
      if (field.nodeName == 'SELECT') {
        field.disabled = false
      } else {
        field.readOnly = false
        this.#removeTooltip(field)
      }
    }

    if (e) {
      e.target?.focus()
    }
  }

  async fitFees(e) {
    e.preventDefault()

    const button = this.fitFeesButtonTarget
    const originalText = button.textContent
    button.disabled = true
    button.textContent = 'Fitting…'
    this.#showFitFeesStatus('Estimating Wise fees…')

    try {
      const url = new URL(button.dataset.fitFeesUrl, window.location.origin)
      url.searchParams.set('value', this.amountFieldTarget.value)
      const response = await fetch(url, {
        headers: { Accept: 'application/json' },
        credentials: 'same-origin',
      })
      const result = await response.json()

      if (!response.ok) throw new Error(result.error || 'Unable to fit fees.')

      this.edit()
      this.amountFieldTarget.value = result.maximum_value
      this.amountFieldTarget.dispatchEvent(new Event('input', { bubbles: true }))
      this.#showFitFeesStatus(result.message)
    } catch (error) {
      this.#showFitFeesStatus(error.message, true)
    } finally {
      button.disabled = false
      button.textContent = originalText
    }
  }

  #memoInput() {
    if (this.enabledValue) {
      // this.memoFieldTarget.focus()
    }
  }

  #buttons() {
    if (!this.hasButtonTarget) {
      return
    }
    if (!this.lockedValue) {
      this.buttonTarget.querySelector('[aria-label=checkmark]').style.display =
        this.enabledValue ? 'block' : 'none'
      this.buttonTarget.querySelector('[aria-label=edit]').style.display = this
        .enabledValue
        ? 'none'
        : 'block'
    }
  }

  #card() {
    if (this.enabledValue && !this.lockedValue) {
      this.cardTarget.classList.add('b--warning')
    } else {
      this.cardTarget.classList.remove('b--warning')
    }
  }

  #label() {
    if (!this.lockedValue && this.hasButtonTarget) {
      this.buttonTarget.ariaLabel =
        this.enabledValue && !this.lockedValue
          ? 'Save edits'
          : 'Edit this expense'
    }
  }

  #move() {
    if (this.enabledValue && !this.lockedValue) {
      this.moveTarget.style.display = 'none'
    }
  }

  #memo() {
    this.memoTarget.innerText =
      this.enabledValue && !this.lockedValue
        ? `Unsaved changes`
        : this.memoValue
    if (this.enabledValue && !this.lockedValue) {
      this.memoTarget.classList.add('warning')
      this.memoTarget.classList.remove('muted')
    } else {
      this.memoTarget.classList.remove('warning')
      // this.memoTarget.classList.add('muted')
    }
  }

  #addTooltip(field, label) {
    if (!label || this.lockedValue || this.enabledValue) return

    const fieldWrapper = document.createElement('div')
    field.parentNode.insertBefore(fieldWrapper, field)
    fieldWrapper.appendChild(field)
    fieldWrapper.classList.add('tooltipped', 'tooltipped--n')
    fieldWrapper.setAttribute('aria-label', label)

    window.attachTooltipListener()
  }

  #removeTooltip(field) {
    const fieldWrapper = field.parentNode
    fieldWrapper.parentNode.insertBefore(field, fieldWrapper)
    fieldWrapper.remove()
  }

  #lightbox() {
    if (this.enabledValue && !this.lockedValue) {
      this.lightboxTarget.style.display = 'block'
      this.cardTarget.style.position = 'relative'
      this.cardTarget.style.zIndex = '11'
      this.lightboxTarget.addEventListener('click', e => {
        e.preventDefault()
        this.formTarget.requestSubmit()
      })
    } else {
      this.lightboxTarget.style.display = 'none'
      this.cardTarget.style.position = 'relative'
      this.cardTarget.style.zIndex = 'auto'
    }
  }

  #showFitFeesStatus(message, error = false) {
    if (!this.hasFitFeesStatusTarget) return

    this.fitFeesStatusTarget.hidden = false
    this.fitFeesStatusTarget.textContent = message
    this.fitFeesStatusTarget.classList.toggle('error', error)
  }
}
