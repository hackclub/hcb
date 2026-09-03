export default () => ({
  scoped_tags: [],
  query: '',

  // The tag arrives as the JSON string on the option's `data-tag`: parsing it
  // here keeps `JSON` out of the directive, where the CSP build cannot see it.
  add(tag) {
    this.scoped_tags.push(JSON.parse(tag))
    this.query = ''
  },

  remove(id) {
    this.scoped_tags = this.scoped_tags.filter(tag => tag.id !== id)
  },
})
