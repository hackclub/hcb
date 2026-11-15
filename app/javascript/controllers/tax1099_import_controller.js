import { Controller } from '@hotwired/stimulus'
import csrf from '../common/csrf'

// Columns are looked up by header name, because Tax1099's W-9 and W-8 exports
// put them in different positions. Their header rows are:
//
//   W-9: Payer Name, Payer TIN, Payee First Name, Payee Middle Name,
//        Payee Last Name, Payee Suffix, EIN/SSN, W9 Requested Date,
//        W9 Received Date, Email Address, Mail Status, Business Type, Filer Type,
//        Address, City, State, Zip Code, Country, W9 Request, W9 Count,
//        W9 Completed Date, W9 Cancel Date
//   W-8: Payer Name, Payer TIN, Payee First Name, Payee Middle Name,
//        Payee Last Name, Payee Suffix, EIN/SSN, W8 Requested Date,
//        W8 Received Date, Email Address, Mail Status (...), Filer Type, Address,
//        City, State, Zip Code, Country, W8 Request, W8 FormType
//
// Each entry lists the header names that column goes by; the first one present
// wins.
const COLUMN = {
  firstName: ['Payee First Name'],
  middleName: ['Payee Middle Name'],
  lastName: ['Payee Last Name'],
  suffix: ['Payee Suffix'],
  tin: ['EIN/SSN'],
  receivedDate: ['W9 Received Date', 'W8 Received Date'],
  completedDate: ['W9 Completed Date'],
  email: ['Email Address'],
  filerType: ['Filer Type'],
  address: ['Address'],
  city: ['City'],
  state: ['State'],
  zipCode: ['Zip Code'],
  country: ['Country'],
  w8FormType: ['W8 FormType'],
}

// Maps each COLUMN key to its index in this CSV's header row, or -1.
function columnIndexes(header) {
  const names = header.map(name => name.trim().toLowerCase())

  return Object.fromEntries(
    Object.entries(COLUMN).map(([key, candidates]) => [
      key,
      candidates
        .map(candidate => names.indexOf(candidate.toLowerCase()))
        .find(index => index !== -1) ?? -1,
    ])
  )
}

// Tax1099 writes W-8 form types like "FormW8-BEN" and "FormW8-BEN-E".
function w8FormType(value) {
  const normalized = value.toUpperCase().replace(/[^0-9A-Z]/g, '')
  if (normalized === 'FORMW8BEN') return 'W8BEN'
  if (normalized === 'FORMW8BENE') return 'W8BENE'
  return ''
}

// Mirrors Tax1099ImportService.us_state_code: the 2-letter code for a US state
// given as its code or full name, in any case, or '' when it's neither.
// usStates maps each code to the names it goes by.
function usStateCode(usStates, value) {
  const trimmed = value.trim()
  if (trimmed.length === 2 && usStates[trimmed.toUpperCase()]) {
    return trimmed.toUpperCase()
  }

  const match = Object.entries(usStates).find(([, names]) =>
    names.some(name => name.toLowerCase() === trimmed.toLowerCase())
  )
  return match ? match[0] : ''
}

// Mirrors Tax1099ImportService.normalize_name, character for character.
function normalizeName(value) {
  return value
    .normalize('NFD')
    .replace(/\p{Mn}/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '')
}

// Mirrors Tax1099ImportService.country_code: the 2-letter code for a country
// given as its code or any of its names, in any case (Tax1099's exports often
// have "INDIA"), or '' when it's neither. codesByName maps each normalized name
// to its code.
function countryCode(codesByName, value) {
  const trimmed = value.trim()
  if (
    trimmed.length === 2 &&
    Object.values(codesByName).includes(trimmed.toUpperCase())
  ) {
    return trimmed.toUpperCase()
  }

  return codesByName[normalizeName(trimmed)] ?? ''
}

// Mirrors Tax1099ImportService.normalize_postal_code.
function normalizePostalCode(value) {
  const normalized = value.replace(/[^0-9A-Za-z]/g, '').toUpperCase()
  return /^\d{9}$/.test(normalized) ? normalized.slice(0, 5) : normalized
}

// Mirrors Tax1099ImportService.entity_type_for, reduced to the one distinction
// the row key needs.
function isPerson(data) {
  if (data.form_type === 'W8BEN') return true
  if (data.form_type === 'W8BENE') return false
  return data.tin_type === 'SSN'
}

// Turns a Tax1099 date (M/D/YYYY, optionally followed by a time) or an ISO date
// into the YYYY-MM-DD a date input takes. Anything else comes back blank so the
// admin has to fill it in rather than import a guess.
function toIsoDate(value) {
  const iso = value.match(/^(\d{4})-(\d{2})-(\d{2})/)
  if (iso) return `${iso[1]}-${iso[2]}-${iso[3]}`

  const us = value.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})\b/)
  if (us) return `${us[3]}-${us[1].padStart(2, '0')}-${us[2].padStart(2, '0')}`

  return ''
}

// Identifies a row that an earlier session already imported, from the row's
// prefilled (pre-review) values. Must stay in step with
// Tax1099ImportService.row_key. Deliberately leaves out the TIN; see
// Tax1099ImportService.imported_row_keys.
function rowKey(data) {
  return [
    data.email.trim().toLowerCase(),
    data.completed_on,
    isPerson(data) ? 'person' : 'business',
    normalizePostalCode(data.zip_code),
  ].join('|')
}

// Tax1099 writes this in the suffix column for rows that have no suffix.
const EMPTY_SUFFIX = 'SEL'

// Mirrors Admin::Tax1099ImportsController::NEW_LEGAL_ENTITY.
const NEW_LEGAL_ENTITY = 'new'

const STATUS = {
  pending: { label: 'Not imported', className: 'bg-muted' },
  importing: { label: 'Importing…', className: 'bg-muted' },
  imported: { label: 'Imported', className: 'bg-success' },
  duplicate: { label: 'Duplicate', className: 'bg-muted' },
  uncertain: { label: 'Unconfirmed', className: 'bg-warning' },
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
    'rowTemplate',
    'rows',
    'summary',
    'summaryTotal',
    'summaryImported',
    'summarySkipped',
    'summaryHidden',
  ]

  static values = {
    createUrl: String,
    legalEntitiesUrl: String,
    fields: Array,
    importedRowKeys: Array,
    usStates: Object,
    countryCodesByName: Object,
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

    this.columns = columnIndexes(rows.shift() ?? [])

    if (rows.length === 0) {
      this.showCsvError('That CSV has no data rows.')
      return
    }

    // Rows already imported are left out entirely, whether in an earlier
    // session or since this page loaded: loading the CSV again (or switching
    // files and back) must not bring a handled row back as "Not imported".
    const importedRowKeys = this.importedRowKeys()
    let hidden = 0

    rows.forEach((cells, index) => {
      if (importedRowKeys.has(rowKey(this.prefill(cells)))) {
        hidden++
        return
      }

      // +1 for the header row, +1 to 1-index, matching what an admin sees in a
      // spreadsheet.
      this.rowsTarget.appendChild(this.buildRow(cells, index + 2))
    })

    // The file itself is never read again and never leaves this function; drop
    // the browser's handle on it too.
    this.csvInputTarget.value = ''

    this.summaryHiddenTarget.textContent = `${hidden} already imported, hidden`
    this.summaryHiddenTarget.hidden = hidden === 0

    this.summaryTarget.hidden = false
    this.updateSummary()

    // ui.js only binds tooltips that exist when it runs, and these rows were
    // just built from the template.
    window.attachTooltipListener?.()
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

  // The form type, email, TIN type and tax classification together decide which legal
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
    if (legalEntityId === '') {
      this.setMessage(
        row,
        'Pick which legal entity this form belongs to before importing.',
        true
      )
      return
    }
    if (legalEntityId) body.append('legal_entity_id', legalEntityId)

    this.setStatus(row, 'importing')
    this.setMessage(row, null)
    row.querySelector('[data-import]').disabled = true

    // A network error or a response that isn't the controller's JSON (a proxy
    // timeout, an error page) says nothing about how far the import got: the
    // server may have kept going after the connection dropped, all the way to
    // TaxBandits. So it's never reported as "nothing was submitted", and the
    // row isn't offered for a retry that could submit it twice.
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
      payload = null
    }

    if (!payload || typeof payload.status !== 'string') {
      this.setStatus(row, 'uncertain')
      this.rememberHandledRow(row)
      this.setMessage(
        row,
        "No answer came back from HCB, so it isn't known whether this row was imported. " +
          "Don't retry it here. Reload the page and load the CSV again: if a form was " +
          'created for this row it will be hidden. If the row still shows, importing it is ' +
          'safe when it has a TIN (a second import of the same TIN is refused). Without a ' +
          "TIN, or if you'd edited its email, date or postal code, check the payee's tax " +
          'forms in HCB first.',
        true
      )
      this.disableRow(row)
      this.updateSummary()
      return
    }

    if (response.ok && payload.status === 'imported') {
      this.setStatus(row, 'imported')
      this.rememberHandledRow(row)
      this.setMessage(
        row,
        `Imported as ${payload.form_id} on ${payload.legal_entity.name}.`
      )
      this.disableRow(row)
      row.querySelector('[data-body]').hidden = true
      row.querySelector('[data-toggle]').textContent = 'Review'
    } else if (payload.status === 'uncertain') {
      // TaxBandits may have accepted it, so this row must not be resubmitted;
      // the message says how to resolve it.
      this.setStatus(row, 'uncertain')
      this.rememberHandledRow(row)
      this.setMessage(row, payload.message, true)
      this.disableRow(row)
    } else if (payload.status === 'duplicate') {
      this.setStatus(row, 'duplicate')
      this.rememberHandledRow(row)
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

  // Every row the server knew about at page load, plus the ones this page has
  // since imported, found to be duplicates, or left unconfirmed.
  importedRowKeys() {
    this.handledRowKeys ??= new Set(this.importedRowKeysValue)
    return this.handledRowKeys
  }

  // Called once a row may exist on the server. Keyed by the row's original CSV
  // values, which is what loadCsv compares against.
  rememberHandledRow(row) {
    this.importedRowKeys().add(row.dataset.rowKey)
  }

  buildRow(cells, rowNumber) {
    const row = this.rowTemplateTarget.content.firstElementChild.cloneNode(true)
    const data = this.prefill(cells)
    row.dataset.rowKey = rowKey(data)

    row.querySelector('[data-row-number]').textContent = `Row ${rowNumber}`
    row.querySelector('[data-row-title]').textContent =
      [data.first_name, data.last_name].filter(Boolean).join(' ') ||
      data.email ||
      '(no name)'

    this.fieldsValue.forEach(key => {
      const input = row.querySelector(`[data-field="${key}"]`)
      if (!input) return

      if (input.type === 'checkbox') {
        input.checked = Boolean(data[key])
      } else {
        input.value = data[key] ?? ''
      }
    })

    this.showFieldsForFormType(row)

    return row
  }

  formTypeChanged(event) {
    const row = event.target.closest('[data-row]')

    this.showFieldsForFormType(row)
    this.refreshLegalEntities(row)
  }

  // Hides the fields that don't apply to the row's form type, e.g. federal tax
  // classification on a W-8. Their values are left alone; the server ignores
  // them for form types they don't apply to.
  showFieldsForFormType(row) {
    const formType = row.querySelector('[data-field="form_type"]').value

    row.querySelectorAll('[data-only-for]').forEach(element => {
      element.hidden = !element.dataset.onlyFor.split(' ').includes(formType)
    })
  }

  // Mirrors Tax1099ImportService's expectations. Tax1099's export puts a
  // business's name in the "Payee Last Name" column (there's no separate
  // business-name column), but TaxBandits wants the entity name in FirstNm, so
  // it's moved here rather than at submission time — that way the admin reviews
  // it in the field it will actually be sent as.
  prefill(cells) {
    const cell = key => (cells[this.columns[key]] ?? '').trim()

    // Only the W-8 export has a W8 FormType column.
    const isW8Export = this.columns.w8FormType !== -1
    const formType = isW8Export ? w8FormType(cell('w8FormType')) : 'W9'

    const tin = cell('tin')
    // A formatted SSN (123-45-6789) has two dashes; an EIN (12-3456789) has one.
    const isBusiness = isW8Export
      ? formType === 'W8BENE'
      : (tin.match(/-/g) || []).length !== 2
    const suffix = cell('suffix')

    // The W-8 export can put an individual's whole name in the last name
    // column, so it moves to first name when that's empty.
    const moveLastToFirst = isBusiness || (isW8Export && !cell('firstName'))

    return {
      form_type: formType,
      first_name: moveLastToFirst ? cell('lastName') : cell('firstName'),
      middle_name: cell('middleName'),
      last_name: moveLastToFirst ? '' : cell('lastName'),
      suffix: suffix === EMPTY_SUFFIX ? '' : suffix,
      tin,
      tin_type: isW8Export ? 'FTIN' : isBusiness ? 'EIN' : 'SSN',
      // An SSN filer can still be a sole proprietor rather than an individual,
      // so this is only prefilled when Tax1099's Filer Type agrees. Everything
      // else is left blank for the admin to pick.
      federal_tax_classification:
        !isW8Export &&
        !isBusiness &&
        cell('filerType').toLowerCase() === 'individual'
          ? 'Individual'
          : '',
      // Not in either export; always picked from the signed W-8BEN-E.
      ch3_status: '',
      // Imports are taken as verified unless the admin unchecks it.
      tin_verified: '1',
      // Never assumed from a blank TIN; ticked by the admin from the signed W-8.
      ftin_not_legally_required: '',
      // An individual usually signs their own W-8BEN; a W-8BEN-E's signer isn't
      // in the export, so it's left for the admin to copy from the PDF.
      signer_name:
        formType === 'W8BEN'
          ? [cell('firstName'), cell('middleName'), cell('lastName')]
              .filter(Boolean)
              .join(' ')
          : '',
      address1: cell('address'),
      city: cell('city'),
      // Some Tax1099 rows spell a W-9's state out ("Massachusetts"); it's sent
      // as its code. One that isn't a recognisable US state is left as it is
      // for the admin to fix, which the server insists on.
      state:
        formType === 'W9'
          ? usStateCode(this.usStatesValue, cell('state')) || cell('state')
          : cell('state'),
      zip_code: cell('zipCode'),
      // Sent as its code. One that isn't a recognisable country is left as it
      // is for the admin to fix, which the server insists on. A W-9's is
      // always US, and not used.
      country:
        countryCode(this.countryCodesByNameValue, cell('country')) ||
        cell('country'),
      email: cell('email'),
      // When the form was actually completed, so the imported form ranks
      // correctly against any the payee completes later. Received is the
      // fallback for rows Tax1099 never stamped as completed, and the only
      // date the W-8 export has.
      completed_on:
        toIsoDate(cell('completedDate')) || toIsoDate(cell('receivedDate')),
    }
  }

  readFields(row) {
    const data = {}

    this.fieldsValue.forEach(key => {
      const input = row.querySelector(`[data-field="${key}"]`)
      if (!input) {
        data[key] = ''
      } else if (input.type === 'checkbox') {
        data[key] = input.checked ? '1' : ''
      } else {
        data[key] = input.value.trim()
      }
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

    // Only a W-9 needs the TIN type and classification to know the entity
    // shape; a W-8's form type alone decides it.
    if (
      !data.email ||
      !data.form_type ||
      (data.form_type === 'W9' &&
        (!data.tin_type || !data.federal_tax_classification))
    ) {
      picker.hidden = true
      return
    }

    const url = new URL(this.legalEntitiesUrlValue, window.location.origin)
    url.searchParams.set('email', data.email)
    url.searchParams.set('form_type', data.form_type)
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
    const options = [new Option('— pick one —', '')]
    payload.legal_entities.forEach(entity => {
      options.push(
        new Option(`${entity.name} (${entity.entity_type})`, entity.id)
      )
    })
    options.push(new Option('Create a new legal entity', NEW_LEGAL_ENTITY))

    select.replaceChildren(...options)
    select.value = previous
    picker.hidden = false
  }

  // null when there's nothing to pick; '' when there is and nothing was picked.
  selectedLegalEntityId(row) {
    const picker = row.querySelector('[data-legal-entity-picker]')
    if (picker.hidden) return null

    return row.querySelector('[data-legal-entity-select]').value
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

    // The file itself is dropped, but the picker keeps showing its name
    // (disabled) as a record of what went with this row. Its clear button
    // would only reset a picker that can no longer be used, so hide it.
    row.querySelector('[data-pdf]').value = ''
    row
      .querySelectorAll('[data-file-upload-target="preview"]')
      .forEach(element => {
        element.disabled = true
      })
    row
      .querySelectorAll('[data-file-upload-target="clear"]')
      .forEach(element => {
        element.style.display = 'none'
      })
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
    this.summaryImportedTarget.textContent = `${count('imported')} imported`
    this.summarySkippedTarget.textContent = `${count('skipped') + count('duplicate')} skipped`
  }
}
