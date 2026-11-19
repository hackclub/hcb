import sweetalert from 'sweetalert'
import { addLayer, removeLayer } from '../layers'

// An open modal <dialog> makes the rest of the page inert, SweetAlert's overlay
// included, so the alert gets a top-layer dialog of its own while one is open.
export default function swal(...args) {
  const alert = sweetalert(...args)
  if (!document.querySelector('dialog:modal')) return alert

  const layer = document.createElement('dialog')
  layer.className = 'swal-layer'
  layer.append(document.querySelector('.swal-overlay'))
  // Only answering the alert closes it, not a close request like Android's back gesture
  layer.addEventListener('cancel', event => event.preventDefault())
  document.body.append(layer)
  layer.showModal()
  // SweetAlert answers Escape itself; as the top layer, it keeps Escape from the modal beneath
  addLayer(layer, () => {})

  alert.finally(() => {
    removeLayer(layer)
    document.body.append(layer.firstElementChild)
    layer.remove()
  })
  return alert
}
