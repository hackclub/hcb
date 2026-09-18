import swal from 'sweetalert'
import $ from 'jquery'
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

// jquery-ujs disables `data-disable-with` elements shortly after every submit
// event; when the confirmation aborts the submission, nothing re-enables them.
function reenableFormElements(formElement) {
  if (!formElement || !$.rails) return

  $(formElement)
    .find($.rails.enableSelector)
    .each((_, element) => {
      if ($(element).data('ujs:disabled')) $.rails.enableFormElement($(element))
    })
}

Turbo.config.forms.confirm = async (message, formElement, submitter) => {
  const dangerMode = Boolean(
    submitter?.hasAttribute('data-turbo-confirm-danger') ||
    formElement?.hasAttribute('data-turbo-confirm-danger')
  )
  const confirmed = await showConfirm(message, { dangerMode })

  if (!confirmed) reenableFormElements(formElement)

  return confirmed
}
window.showConfirm = showConfirm
window.swal = swal

export default showConfirm
