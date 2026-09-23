export default ({ create_url }) => ({
  scoped_tags: [],
  query: '',

  // A template literal is out of reach of the CSP build's directive parser, so
  // the "create this tag" href is assembled here.
  get create_tag_url() {
    return `${create_url}?name=${this.query}`
  },

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
