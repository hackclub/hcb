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
  ]
  static values = {
    enabled: { type: Boolean, default: false },
    locked: { type: Boolean, default: false },
    memo: { type: String, default: 'Untitled Expense' },
  }

  connect() {
    this._handleKeydown = (e) => {
      if (e.key === 'Escape' && this.enabledValue) {
        this.formTarget.reset()
        this.close()
      }
    }
    document.addEventListener('keydown', this._handleKeydown)

    this._handleLightboxClick = (e) => {
      e.preventDefault()
      this.formTarget.requestSubmit()
    }

    for (const field of this.fieldTargets) {
      if (field.nodeName == 'SELECT') {
        field.disabled = !this.enabledValue
      } else {
        field.readOnly = !this.enabledValue
        field.addEventListener('dblclick', () => this.edit())
        this.#addTooltip(field, 'Double-click to edit...')
      }
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

  disconnect() {
    document.removeEventListener('keydown', this._handleKeydown)
    this.lightboxTarget.removeEventListener('click', this._handleLightboxClick)
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

    const wrapper = field.closest('[data-tooltip-wrapper]')
    if (!wrapper) return

    wrapper.classList.add('tooltipped', 'tooltipped--n')
    wrapper.setAttribute('aria-label', label)
  }

  #removeTooltip(field) {
    const wrapper = field.closest('[data-tooltip-wrapper]')
    if (!wrapper) return

    wrapper.classList.remove('tooltipped', 'tooltipped--n')
    wrapper.removeAttribute('aria-label')
  }

  #lightbox() {
    if (this.enabledValue && !this.lockedValue) {
      this.lightboxTarget.style.display = 'block'
      this.cardTarget.style.position = 'relative'
      this.cardTarget.style.zIndex = '11'
      this.lightboxTarget.addEventListener('click', this._handleLightboxClick)
    } else {
      this.lightboxTarget.style.display = 'none'
      this.cardTarget.style.position = 'relative'
      this.cardTarget.style.zIndex = 'auto'
      this.lightboxTarget.removeEventListener('click', this._handleLightboxClick)
    }
  }
}
