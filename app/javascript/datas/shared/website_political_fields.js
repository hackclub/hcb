// Shared by the two application project-info forms. Both toggle `required` (and
// clear the value) on a field elsewhere in the form, which needs `document` —
// a global the CSP build will not resolve from a directive expression.
//
// Plain methods rather than getters on purpose: the forms spread this object
// into their own, and spreading would invoke a getter instead of carrying it
// over.
export default {
  set_has_website(value) {
    this.has_website = value

    const field = document.getElementById('website_url_field')
    field.required = this.has_website === 'true'
    if (this.has_website === 'false') field.value = ''
  },

  set_has_political(value) {
    this.has_political = value

    document.getElementById('political_description_field').required =
      this.has_political === 'true'
  },
}
