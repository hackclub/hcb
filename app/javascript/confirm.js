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

Turbo.config.forms.confirm = (message, formElement, submitter) => {
  const dangerMode = Boolean(
    submitter?.hasAttribute('data-turbo-confirm-danger') ||
      formElement?.hasAttribute('data-turbo-confirm-danger')
  )
  return showConfirm(message, { dangerMode })
}
window.showConfirm = showConfirm
window.swal = swal

export default showConfirm
