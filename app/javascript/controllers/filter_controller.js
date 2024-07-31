import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'tagsLabel',
    'usersLabel',
    'typesLabel',
    'datesLabel',
    'amountsLabel',
    'tags',
    'users',
    'types',
    'dates',
    'amounts',
  ]

  selectTags(mouseEvent) {
    this.tagsLabelTarget.dataset.filterMenuLabelSelected = mouseEvent
      ? 'true'
      : 'false'
    this.tagsTarget.dataset.filterMenuSelected = mouseEvent ? 'true' : 'false'
    if (mouseEvent !== undefined) {
      this.selectTypes()
      this.selectUsers()
      this.selectDates()
      this.selectAmounts()
    }
  }

  selectUsers(mouseEvent) {
    this.usersLabelTarget.dataset.filterMenuLabelSelected = mouseEvent
      ? 'true'
      : 'false'
    this.usersTarget.dataset.filterMenuSelected = mouseEvent ? 'true' : 'false'
    if (mouseEvent !== undefined) {
      this.selectTypes()
      this.selectDates()
      this.selectAmounts()
      if (this.hasTagsTarget) {
        this.selectTags()
      }
    }
  }

  selectTypes(mouseEvent) {
    this.typesLabelTarget.dataset.filterMenuLabelSelected = mouseEvent
      ? 'true'
      : 'false'
    this.typesTarget.dataset.filterMenuSelected = mouseEvent ? 'true' : 'false'
    if (mouseEvent !== undefined) {
      this.selectUsers()
      this.selectDates()
      this.selectAmounts()
      if (this.hasTagsTarget) {
        this.selectTags()
      }
    }
  }

  selectDates(mouseEvent) {
    this.datesLabelTarget.dataset.filterMenuLabelSelected = mouseEvent
      ? 'true'
      : 'false'
    this.datesTarget.dataset.filterMenuSelected = mouseEvent ? 'true' : 'false'
    if (mouseEvent !== undefined) {
      this.selectTypes()
      this.selectUsers()
      this.selectAmounts()
      if (this.hasTagsTarget) {
        this.selectTags()
      }
    }
  }

  selectAmounts(mouseEvent) {
    this.amountsLabelTarget.dataset.filterMenuLabelSelected = mouseEvent
      ? 'true'
      : 'false'
    this.amountsTarget.dataset.filterMenuSelected = mouseEvent
      ? 'true'
      : 'false'
    if (mouseEvent !== undefined) {
      this.selectUsers()
      this.selectDates()
      this.selectTypes()
      if (this.hasTagsTarget) {
        this.selectTags()
      }
    }
  }
}
