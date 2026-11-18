import sweetalert from 'sweetalert'

// An open modal <dialog> makes the rest of the page inert, SweetAlert's overlay
// included, so the alert gets a top-layer dialog of its own while one is open.
export default function swal(...args) {
  const alert = sweetalert(...args)
  if (!document.querySelector('dialog:modal')) return alert

  const layer = document.createElement('dialog')
  layer.className = 'swal-layer'
  layer.append(document.querySelector('.swal-overlay'))
  // SweetAlert handles Escape itself, resolving the alert
  layer.addEventListener('cancel', event => event.preventDefault())
  document.body.append(layer)
  layer.showModal()

  alert.finally(() => {
    document.body.append(layer.firstElementChild)
    layer.remove()
  })
  return alert
}
