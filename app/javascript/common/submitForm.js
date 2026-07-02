import csrf, { csrfParam } from './csrf'

/**
 * Creates and submits a hidden form with the given parameters as inputs.
 *
 * @param {string} url
 * @param {Object} params
 * @param {Object} options
 * @param {boolean} options.turbo - set to false to bypass Turbo Drive (default: true)
 */
export default function submitForm(url, params, { turbo = true } = {}) {
  const form = document.createElement('form')
  form.action = url
  form.method = 'POST'
  form.style.display = 'none'
  if (!turbo) form.dataset.turbo = 'false'

  params[csrfParam()] = csrf()

  for (const key in params) {
    const value = params[key]

    const input = document.createElement('input')
    input.type = 'hidden'
    input.name = key
    input.value = value

    form.appendChild(input)
  }

  document.body.appendChild(form)

  form.requestSubmit()
}
