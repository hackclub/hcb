let dialog = null
let currentResolve = null

function buildDialog() {
  const el = document.createElement('dialog')
  el.id = 'hcb-confirm'
  el.innerHTML = `
    <p class="hcb-confirm__message"></p>
    <div class="hcb-confirm__actions">
      <button class="btn hcb-confirm__cancel" type="button">Cancel</button>
      <button class="btn hcb-confirm__ok" type="button">Confirm</button>
    </div>
  `

  // Native dialog cancel (Escape key) — prevent browser default close so we can resolve the promise
  el.addEventListener('cancel', e => {
    e.preventDefault()
    settle(false)
  })

  // Arrow-key navigation between buttons
  el.addEventListener('keydown', e => {
    if (e.key === 'ArrowLeft') {
      e.preventDefault()
      el.querySelector('.hcb-confirm__cancel').focus()
    } else if (e.key === 'ArrowRight') {
      e.preventDefault()
      el.querySelector('.hcb-confirm__ok').focus()
    }
  })

  el.querySelector('.hcb-confirm__cancel').addEventListener('click', () => settle(false))
  el.querySelector('.hcb-confirm__ok').addEventListener('click', () => settle(true))

  document.body.appendChild(el)
  return el
}

function getDialog() {
  if (!dialog) dialog = buildDialog()
  return dialog
}

function settle(value) {
  getDialog().close()
  if (currentResolve) {
    currentResolve(value)
    currentResolve = null
  }
}

// message    - string shown in the dialog
// second arg - either an HTMLElement (passed by Turbo.setConfirmMethod) or an options object
//              { confirmText, confirmClass } for direct JS callers
export function confirm(message, elementOrOptions = {}) {
  const el = getDialog()

  let confirmText = 'Confirm'
  let confirmClass = 'bg-error'

  if (elementOrOptions instanceof HTMLElement) {
    confirmText = elementOrOptions.dataset.confirmText || confirmText
    confirmClass = elementOrOptions.dataset.confirmClass || confirmClass
  } else {
    confirmText = elementOrOptions.confirmText || confirmText
    confirmClass = elementOrOptions.confirmClass || confirmClass
  }

  el.querySelector('.hcb-confirm__message').textContent = message
  const okBtn = el.querySelector('.hcb-confirm__ok')
  okBtn.textContent = confirmText
  okBtn.className = `btn ${confirmClass}`

  el.showModal()
  okBtn.focus()

  return new Promise(res => {
    currentResolve = res
  })
}
