// The one place that names the Alpine build, so a component needing the
// instance itself (`Alpine.$persist`, say) can't reach a second copy.
//
// The CSP build swaps Alpine's `new Function(...)` compiler for a small parser
// and interpreter, so no directive needs `script-src 'unsafe-eval'`. It only
// understands a subset of JS: a single expression per directive, no arrow
// functions, no template literals, no optional chaining, and no globals.
import Alpine from '@alpinejs/csp'

export default Alpine
