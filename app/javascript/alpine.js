// The one place that names the Alpine build, so a component needing the
// instance itself (`Alpine.$persist`, say) can't reach a second copy.
import Alpine from 'alpinejs'

export default Alpine
