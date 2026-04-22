import $ from 'jquery'
import { Turbo } from '@hotwired/turbo-rails'

function showConfirm(message, { title = 'Are you sure?', confirmText = 'Confirm', confirmClass = 'bg-error' } = {}) {
  return new Promise((resolve) => {
    const modal = document.getElementById('confirm_modal')

    modal.querySelector('#confirm_modal_title').textContent = title
    modal.querySelector('#confirm_modal_message').textContent = message

    const ok = modal.querySelector('#confirm_modal_ok')
    ok.textContent = confirmText
    ok.className = `btn w-full ${confirmClass}`

    let confirmed = false

    function onOk() {
      confirmed = true
      $.modal.close()
    }

    $(modal).one('modal:close', () => {
      ok.removeEventListener('click', onOk)
      resolve(confirmed)
    })

    ok.addEventListener('click', onOk)
    $(modal).modal({ fadeDuration: 200, fadeDelay: 0.75 })
  })
}

Turbo.config.confirmationMethod = message => showConfirm(message)
window.showConfirm = showConfirm

export default showConfirm
