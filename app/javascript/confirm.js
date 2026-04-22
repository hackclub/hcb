import swal from 'sweetalert'
import { Turbo } from '@hotwired/turbo-rails'

function showConfirm(message, { title = 'Are you sure?', confirmText = 'Confirm', dangerMode = false } = {}) {
  return swal({ title, text: message, buttons: ['Cancel', confirmText], dangerMode }).then(v => !!v)
}

Turbo.config.confirmationMethod = message => showConfirm(message, { dangerMode: true })
window.showConfirm = showConfirm

export default showConfirm
