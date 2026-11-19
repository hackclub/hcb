import sweetalert from 'sweetalert'
import { addLayer, removeLayer } from '../layers'

// SweetAlert shows over everything, modals included (its overlay's z-index is
// above theirs), and answers Escape and Tab itself.
export default function swal(...args) {
  // What asked, to hand focus back to: SweetAlert leaves it on <body>
  const asker = document.activeElement
  const alert = sweetalert(...args)
  // On top of the Escape stack, so Escape doesn't also close a modal beneath
  const layer = {}
  addLayer(layer, () => {})

  alert.finally(() => {
    removeLayer(layer)
    // Unless another alert has opened since, or focus has moved on
    if (
      asker?.isConnected &&
      !document.querySelector('.swal-overlay--show-modal') &&
      (document.activeElement === document.body ||
        document.activeElement?.closest('.swal-overlay'))
    )
      asker.focus({ preventScroll: true })
  })
  return alert
}
