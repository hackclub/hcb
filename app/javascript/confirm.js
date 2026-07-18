import swal from 'sweetalert'
import { Turbo } from '@hotwired/turbo-rails'

function showConfirm(
  message,
  { title = 'Are you sure?', confirmText = 'Confirm', dangerMode = false } = {}
) {
  return swal({
    title,
    text: message,
    buttons: ['Cancel', confirmText],
    dangerMode,
  }).then(v => !!v)
}

async function showTypeToConfirm(
  message,
  phrase,
  { title = 'Are you sure?', afterMessage = null } = {}
) {
  const warned = await swal({
    title,
    text: message,
    icon: 'warning',
    buttons: ['Cancel', "Yes, I'm sure"],
    dangerMode: true,
  })
  if (!warned) return false

  const typed = await swal({
    title: 'Confirm by typing',
    text: `Type "${phrase}" below to confirm:`,
    content: {
      element: 'input',
      attributes: {
        placeholder: phrase,
        type: 'text',
      },
    },
    buttons: ['Cancel', 'Confirm'],
    dangerMode: true,
  })
  if (typed?.trim() !== phrase) {
    if (typed !== null) {
      await swal(
        'Not confirmed',
        'What you typed did not match.',
        'error'
      )
    }
    return false
  }

  if (afterMessage) {
    await swal('One more thing', afterMessage, 'info')
  }

  return true
}

Turbo.config.forms.confirm = (message, formElement, submitter) => {
  const dangerMode = Boolean(
    submitter?.hasAttribute('data-turbo-confirm-danger') ||
    formElement?.hasAttribute('data-turbo-confirm-danger')
  )

  const phrase =
    submitter?.getAttribute('data-turbo-confirm-type-phrase') ||
    formElement?.getAttribute('data-turbo-confirm-type-phrase')

  if (phrase) {
    const afterMessage =
      submitter?.getAttribute('data-turbo-confirm-after-message') ||
      formElement?.getAttribute('data-turbo-confirm-after-message')

    return showTypeToConfirm(message, phrase, { afterMessage })
  }

  return showConfirm(message, { dangerMode })
}
window.showConfirm = showConfirm
window.showTypeToConfirm = showTypeToConfirm
window.swal = swal

export default showConfirm
