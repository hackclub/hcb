// Picking an affiliation type without saving should warn on the way out. The
// confirmation lives on the footer's submit button, outside this form, so it is
// stamped on by hand — `document` and arrow functions are both out of reach of a
// directive under the CSP build.
const UNSAVED_AFFILIATION =
  'You have an unsaved affiliation. Are you sure you want to continue?'

export default ({ disabled }) => ({
  type: '',
  disabled,

  init() {
    this.$watch('type', this.syncConfirmation.bind(this))
  },

  syncConfirmation(type) {
    const submit = document.getElementById('submit_application')
    if (!submit) return

    if (type) {
      submit.setAttribute('data-turbo-confirm', UNSAVED_AFFILIATION)
    } else {
      submit.removeAttribute('data-turbo-confirm')
    }
  },
})
