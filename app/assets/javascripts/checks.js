/* global BK, $ */

const amountToCheckWords = amount => {
  let [dollarsString = '', centsString = ''] = amount.split('.')

  const dollars = dollarsString ? +dollarsString.replace(/\D/g, "") : 0
  let cents = centsString ? +centsString.slice(0, 2) : 0
  if (centsString.length === 1) {
    cents *= 10
  }
  const words = `${BK.numToWords(dollars)} ${cents > 0 ? `and ${cents}/100` : 'and 00/100'
    }`
  return words
}

$(document).on('turbo:load', function () {
  $('[id^="increase_check_"]').on('change paste keyup input', event => {
    const fieldName = event.currentTarget.id.replace('increase_check_', '')

    if (fieldName == 'memo') {
      $('[data-behavior~="check_memo"]').text(
        $(event.currentTarget).val() || '　'
      )
    }

    if (fieldName == 'amount') {
      let amount = $(event.currentTarget).val()
      if (amount.includes('.')) {
        amount = amount.slice(0, amount.indexOf('.') + 3)
      }
      const words = amountToCheckWords(amount)

      $('[data-behavior~="check_amount"]').text(amount ? event.currentTarget.valueAsNumber?.toLocaleString("en-US", { minimumFractionDigits: 2 }) : '　')
      $('[data-behavior~="check_amount_words"]').text(words || '　')
    }

    if (fieldName == 'recipient_name') {
      $('[data-behavior~="check_orderof"]').text(
        $(event.currentTarget).val() || '　'
      )
    }
  })
})

$(document).on('turbo:load', function () {
  // make the check have words on the show
  if ($('[data-behavior~="fill_check_words"]').length == 1) {
    const amount = $('[data-behavior~="fill_check_words"]')
      .data()
      .checkAmount.toString()
    const words = amountToCheckWords(amount)

    $('[data-behavior~="fill_check_words"]').text(words)
  }

  $('[data-behavior~="check_memo_field"]').on(
    'change paste keyup input',
    event => {
      let characters = $(event.currentTarget).val().length

      $('[data-behavior~="check_characters_update"').text(
        `${40 - characters} characters left`
      )
    }
  )
})
