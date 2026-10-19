import { Controller } from '@hotwired/stimulus'
import csrf from '../common/csrf'

// Column positions in Tax1099's W-9 export. Its header row is:
//
//   Payer Name, Payer TIN, Payee First Name, Payee Middle Name, Payee Last Name,
//   Payee Suffix, EIN/SSN, W9 Requested Date, W9 Received Date, Email Address,
//   Mail Status, Business Type, Filer Type, Address, City, State, Zip Code,
//   Country, W9 Request, W9 Count, W9 Completed Date, W9 Cancel Date
const COLUMN = {
  firstName: 2,
  middleName: 3,
  lastName: 4,
  suffix: 5,
  tin: 6,
  email: 9,
  filerType: 12,
  address: 13,
  city: 14,
  state: 15,
  zipCode: 16,
}

// Tax1099 writes this in the suffix column for rows that have no suffix.
const EMPTY_SUFFIX = 'SEL'

const STATUS = {
  pending: { label: 'Not imported', className: 'bg-muted' },
  importing: { label: 'Importing…', className: 'bg-muted' },
  imported: { label: 'Imported', className: 'bg-success' },
  review: { label: 'Imported — needs legal entity', className: 'bg-warning' },
  duplicate: { label: 'Duplicate', className: 'bg-muted' },
  skipped: { label: 'Skipped', className: 'bg-muted' },
  failed: { label: 'Failed', className: 'bg-error' },
}

// A minimal RFC 4180 reader. Enough for Tax1099's export (quoted fields,
// doubled quotes, embedded newlines, CRLF) and small enough to keep the CSV in
// the browser, which is the entire point of this page.
function parseCsv(text) {
  if (text.charCodeAt(0) === 0xfeff) text = text.slice(1)

  const rows = []
  let row = []
  let field = ''
  let quoted = false

  for (let i = 0; i < text.length; i++) {
    const char = text[i]

    if (quoted) {
      if (char !== '"') {
        field += char
      } else if (text[i + 1] === '"') {
        field += '"'
        i++
      } else {
        quoted = false
      }
      continue
    }

    if (char === '"') {
      quoted = true
    } else if (char === ',') {
      row.push(field)
      field = ''
    } else if (char === '\n') {
      row.push(field)
      rows.push(row)
      row = []
      field = ''
    } else if (char !== '\r') {
      field += char
    }
  }

  if (field !== '' || row.length > 0) {
    row.push(field)
    rows.push(row)
  }

  // Trailing newlines leave behind rows that are entirely empty.
  return rows.filter(cells => cells.some(cell => cell.trim() !== ''))
}

export default class extends Controller {
  static targets = [
    'csvInput',
    'csvError',
    'intro',
    'rowTemplate',
    'rows',
    'summary',
    'summaryTotal',
    'summaryImported',
    'summarySkipped',
    'summaryReview',
  ]

  static values = {
    createUrl: String,
    legalEntitiesUrl: String,
    fields: Array,
  }

  async loadCsv(event) {
    const file = event.target.files[0]
    if (!file) return

    this.csvErrorTarget.hidden = true
    this.rowsTarget.replaceChildren()

    let rows
    try {
      rows = parseCsv(await file.text())
    } catch {
      this.showCsvError("That file couldn't be read as a CSV.")
      return
    }

    // Drop the header row.
    rows.shift()

    if (rows.length === 0) {
      this.showCsvError('That CSV has no data rows.')
      return
    }

    rows.forEach((cells, index) => {
      // +1 for the header row, +1 to 1-index, matching what an admin sees in a
      // spreadsheet.
      this.rowsTarget.appendChild(this.buildRow(cells, index + 2))
    })

    // The file itself is never read again and never leaves this function; drop
    // the browser's handle on it too.
    this.csvInputTarget.value = ''

    this.introTarget.hidden = true
    this.summaryTarget.hidden = false
    this.updateSummary()
  }

  toggleRow(event) {
    const row = event.target.closest('[data-row]')
    const body = row.querySelector('[data-body]')

    body.hidden = !body.hidden
    row.querySelector('[data-toggle]').textContent = body.hidden
      ? 'Review'
      : 'Hide'

    if (!body.hidden) this.refreshLegalEntities(row)
  }

  // The email, TIN type and tax classification together decide which legal
  // entity a form lands on, so any of them changing invalidates the answer.
  entityShapeChanged(event) {
    this.refreshLegalEntities(event.target.closest('[data-row]'))
  }

  pdfChanged(event) {
    const row = event.target.closest('[data-row]')
    const file = event.target.files[0]

    if (file && file.type && file.type !== 'application/pdf') {
      this.setMessage(row, 'That file is not a PDF.', true)
    } else {
      this.setMessage(row, null)
    }
  }

  skip(event) {
    const row = event.target.closest('[data-row]')

    this.setStatus(row, 'skipped')
    this.disableRow(row)
    row.querySelector('[data-body]').hidden = true
    row.querySelector('[data-toggle]').textContent = 'Review'
    this.updateSummary()
  }

  async import(event) {
    const row = event.target.closest('[data-row]')
    const data = this.readFields(row)
    const pdf = row.querySelector('[data-pdf]').files[0]

    if (!pdf) {
      this.setMessage(row, 'Attach the signed W-9 PDF before importing.', true)
      return
    }

    const body = new FormData()
    this.fieldsValue.forEach(key => body.append(key, data[key] ?? ''))
    body.append('pdf', pdf)

    const legalEntityId = this.selectedLegalEntityId(row)
    if (legalEntityId) body.append('legal_entity_id', legalEntityId)

    this.setStatus(row, 'importing')
    this.setMessage(row, null)
    row.querySelector('[data-import]').disabled = true

    let response
    let payload
    try {
      response = await fetch(this.createUrlValue, {
        method: 'POST',
        headers: { Accept: 'application/json', 'X-CSRF-Token': csrf() },
        body,
      })
      payload = await response.json()
    } catch {
      this.setStatus(row, 'failed')
      this.setMessage(
        row,
        'The request never completed. Nothing was submitted; try again.',
        true
      )
      row.querySelector('[data-import]').disabled = false
      return
    }

    if (response.ok && payload.status === 'imported') {
      this.setStatus(row, payload.needs_manual_review ? 'review' : 'imported')
      this.setMessage(
        row,
        payload.needs_manual_review
          ? `Imported as ${payload.form_id}. No legal entity was chosen, so assign one by hand.`
          : `Imported as ${payload.form_id} on ${payload.legal_entity.name}.`
      )
      this.disableRow(row)
      row.querySelector('[data-body]').hidden = true
      row.querySelector('[data-toggle]').textContent = 'Review'
    } else if (payload.status === 'duplicate') {
      this.setStatus(row, 'duplicate')
      this.setMessage(row, payload.message, true)
      this.disableRow(row)
    } else {
      this.setStatus(row, 'failed')
      this.setMessage(row, payload.message || 'The import failed.', true)
      row.querySelector('[data-import]').disabled = false
    }

    this.updateSummary()
  }

  /* Building rows */

  buildRow(cells, rowNumber) {
    const row = this.rowTemplateTarget.content.firstElementChild.cloneNode(true)
    const data = this.prefill(cells)

    row.querySelector('[data-row-number]').textContent = `Row ${rowNumber}`
    row.querySelector('[data-row-title]').textContent =
      [data.first_name, data.last_name].filter(Boolean).join(' ') ||
      data.email ||
      '(no name)'

    this.fieldsValue.forEach(key => {
      const input = row.querySelector(`[data-field="${key}"]`)
      if (input) input.value = data[key] ?? ''
    })

    return row
  }

  // Mirrors Tax1099ImportService's expectations. Tax1099's export puts a
  // business's name in the "Payee Last Name" column (there's no separate
  // business-name column), but TaxBandits wants the entity name in FirstNm, so
  // it's moved here rather than at submission time — that way the admin reviews
  // it in the field it will actually be sent as.
  prefill(cells) {
    const cell = index => (cells[index] ?? '').trim()

    const tin = cell(COLUMN.tin)
    // A formatted SSN (123-45-6789) has two dashes; an EIN (12-3456789) has one.
    const isBusiness = (tin.match(/-/g) || []).length !== 2
    const suffix = cell(COLUMN.suffix)

    return {
      first_name: isBusiness ? cell(COLUMN.lastName) : cell(COLUMN.firstName),
      middle_name: cell(COLUMN.middleName),
      last_name: isBusiness ? '' : cell(COLUMN.lastName),
      suffix: suffix === EMPTY_SUFFIX ? '' : suffix,
      tin,
      tin_type: isBusiness ? 'EIN' : 'SSN',
      // An SSN filer can still be a sole proprietor rather than an individual,
      // so this is only prefilled when Tax1099's Filer Type agrees. Everything
      // else is left blank for the admin to pick.
      federal_tax_classification:
        !isBusiness && cell(COLUMN.filerType).toLowerCase() === 'individual'
          ? 'Individual'
          : '',
      address1: cell(COLUMN.address),
      city: cell(COLUMN.city),
      state: cell(COLUMN.state),
      zip_code: cell(COLUMN.zipCode),
      email: cell(COLUMN.email),
    }
  }

  readFields(row) {
    const data = {}

    this.fieldsValue.forEach(key => {
      const input = row.querySelector(`[data-field="${key}"]`)
      data[key] = input ? input.value.trim() : ''
    })

    return data
  }

  /* Legal entities */

  // Asks the server which business legal entities the payee already has, so the
  // admin can answer the question before the row (and its TIN, and its PDF) is
  // submitted. Only the email and the entity shape are sent.
  async refreshLegalEntities(row) {
    const data = this.readFields(row)
    const picker = row.querySelector('[data-legal-entity-picker]')
    const select = row.querySelector('[data-legal-entity-select]')

    if (!data.email || !data.tin_type || !data.federal_tax_classification) {
      picker.hidden = true
      return
    }

    const url = new URL(this.legalEntitiesUrlValue, window.location.origin)
    url.searchParams.set('email', data.email)
    url.searchParams.set('tin_type', data.tin_type)
    url.searchParams.set(
      'federal_tax_classification',
      data.federal_tax_classification
    )

    // Responses can arrive out of order; only the newest one may touch the DOM.
    const request = (row.dataset.legalEntityRequest = String(
      Date.now() + Math.random()
    ))

    let payload
    try {
      const response = await fetch(url, {
        headers: { Accept: 'application/json' },
      })
      if (!response.ok) return
      payload = await response.json()
    } catch {
      return
    }

    if (row.dataset.legalEntityRequest !== request) return

    if (payload.legal_entities.length === 0) {
      picker.hidden = true
      select.replaceChildren()
      return
    }

    const previous = select.value
    const options = [new Option('— leave for manual assignment —', '')]
    payload.legal_entities.forEach(entity => {
      options.push(
        new Option(`${entity.name} (${entity.entity_type})`, entity.id)
      )
    })

    select.replaceChildren(...options)
    select.value = previous
    picker.hidden = false
  }

  selectedLegalEntityId(row) {
    const picker = row.querySelector('[data-legal-entity-picker]')
    if (picker.hidden) return null

    return row.querySelector('[data-legal-entity-select]').value || null
  }

  /* Presentation */

  setStatus(row, status) {
    const { label, className } = STATUS[status]
    const badge = row.querySelector('[data-status]')

    badge.textContent = label
    badge.className = `badge ${className}`
    row.dataset.state = status
  }

  setMessage(row, text, isError = false) {
    const message = row.querySelector('[data-message]')

    message.textContent = text ?? ''
    message.hidden = !text
    message.style.color = isError ? 'var(--hcb-primary)' : 'var(--hcb-tx-2)'
  }

  // Once a row has been imported, duplicated, or skipped there is nothing left
  // to send, and re-submitting would create a second form. Freeze it, and drop
  // the PDF the browser is still holding.
  disableRow(row) {
    row
      .querySelectorAll('input, select, button[data-import], button[data-skip]')
      .forEach(element => {
        element.disabled = true
      })

    const pdf = row.querySelector('[data-pdf]')
    pdf.value = ''
  }

  showCsvError(message) {
    this.csvErrorTarget.textContent = message
    this.csvErrorTarget.hidden = false
  }

  updateSummary() {
    const rows = this.rowsTarget.querySelectorAll('[data-row]')
    const count = state =>
      Array.from(rows).filter(row => row.dataset.state === state).length

    this.summaryTotalTarget.textContent = `${rows.length} rows`
    this.summaryImportedTarget.textContent = `${count('imported') + count('review')} imported`
    this.summarySkippedTarget.textContent = `${count('skipped') + count('duplicate')} skipped`
    this.summaryReviewTarget.textContent = `${count('review')} need a legal entity`
  }
}
