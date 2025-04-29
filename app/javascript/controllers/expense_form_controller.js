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

  #memoInput() {
    if (this.enabledValue) {
      console.log(this.memoFieldTarget)
      this.memoFieldTarget?.focus()
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
      this.cardTarget.style.zIndex = '2001'
      document.querySelector('.app__sidebar').style.zIndex = '1'
      this.lightboxTarget.addEventListener('click', e => {
        e.preventDefault()
        this.formTarget.requestSubmit()
      })
    } else {
      this.lightboxTarget.style.display = 'none'
      this.cardTarget.style.position = 'relative'
      this.cardTarget.style.zIndex = 'auto'
      document.querySelector('.app__sidebar').style.zIndex = 'auto'
    }
  }
}
