import swal from 'sweetalert'

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

document.addEventListener('turbo:confirm', (event) => {
  event.preventDefault()
  showConfirm(event.detail.message, { dangerMode: true }).then(confirmed => {
    event.detail.resume(confirmed)
  })
})

window.showConfirm = showConfirm
window.swal = swal

export default showConfirm
