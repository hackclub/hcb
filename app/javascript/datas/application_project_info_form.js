export default ({
  has_website,
  has_political,
  teenager,
  committed,
  description,
}) => ({
  has_website,
  has_political,
  teenager,
  committed,
  description,
  description_word_count: 0,
  init() {
    this.$watch('description', this.setDescriptionWordCount.bind(this))
    this.$watch(
      'description_word_count',
      this.setDescriptionValidity.bind(this)
    )

    this.setDescriptionWordCount(description)
    this.setDescriptionValidity(this.description_word_count)
  },
  setDescriptionWordCount(desc) {
    this.description_word_count = desc.match(/\S+/g)?.length || 0
  },
  setDescriptionValidity(count) {
    if (this.teenager === 'false') {
      const descriptionElement = document.getElementById(
        'event_application_description'
      )

      if (count < 50) {
        descriptionElement.setCustomValidity('Please enter at least 50 words')
      } else {
        descriptionElement.setCustomValidity('')
      }
    }
  },
})
