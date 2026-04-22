import { Controller } from '@hotwired/stimulus'
import { confirm } from '../confirm'

export default class extends Controller {
  // Intercepts a form submit triggered by a button/link.
  // Usage: data-action="click->confirm#submit"
  //        data-confirm-message-param="Are you sure?"
  //        data-confirm-input-name-param="param_name"   (optional — adds a hidden input before submit)
  //        data-confirm-input-value-param="1"           (optional, defaults to "1")
  async submit({ target, params }) {
    const confirmed = await confirm(params.message)
    if (!confirmed) return

    const form = target.closest('form')
    if (params.inputName) {
      const input = Object.assign(document.createElement('input'), {
        type: 'hidden',
        name: params.inputName,
        value: params.inputValue ?? '1',
      })
      form.appendChild(input)
    }
    form.requestSubmit()
  }

  // Intercepts a checkbox uncheck that would otherwise submit a destructive action.
  // Restores the checked state while awaiting, then submits only if confirmed.
  // Usage: data-action="change->confirm#uncheck"
  //        data-confirm-message-param="Are you sure?"
  async uncheck({ target, isTrusted, params }) {
    if (target.checked || !isTrusted) return

    // Restore the checkbox while the dialog is open so the UI stays consistent
    target.checked = true
    const confirmed = await confirm(params.message)
    if (confirmed) {
      target.checked = false
      target.closest('form').requestSubmit()
    } else {
      // Re-dispatch a synthetic change so sibling controllers (e.g. accordion)
      // can react to the restored checked state. isTrusted will be false so
      // this action won't fire again.
      target.dispatchEvent(new Event('change', { bubbles: true }))
    }
  }
}
