#!/usr/bin/env node
// Diffs the old transaction engine against the new ledger for a list of orgs.
//
// Old engine: GET /:slug/transactions_list  (TransactionGroupingEngine + PendingTransactionEngine)
// New engine: GET /:slug/ledger             (Ledger::Query -> Ledger::Item)
//
// Both render the same `<tr class="transaction">` shape, so we scrape both, normalize
// each row to {date, amount, memo, status, tags, receipts, comments, author} and diff.
// Row identity is deliberately ignored: the old engine keys rows by HcbCode hashid and
// the new one by Ledger::Item hashid, so they can never match. Same for the icon/type
// label, whose vocabularies differ between engines. Override with --ignore.
//
// Two known, expected sources of noise:
//
//   * `status`. The old engine renders a status badge only on pending rows
//     (canonical_pending_transactions/_canonical_pending_transaction renders
//     "Pending"/"Declined"/"Reversed"); a settled row never carries one. The new
//     engine renders one for every non-settled Ledger::Item, so reversed, released,
//     rejected, failed, canceled and declined items report old="" new="Reversed"
//     etc. That is the new ledger showing more, not a regression -- run with
//     `--ignore id,type,status` when you want the row set rather than the badges.
//
//   * Ordering of pending rows. The old engine renders every pending transaction
//     above page 1's settled rows; the new engine sorts pending first but paginates
//     them inline. Known and won't-fix, so treat `order diverges at #N` as noise
//     unless the row sets themselves also differ.
//
// Usage:
//   HCB_COOKIE='_hcb_session=...' node scripts/ledger_diff.mjs hq bank my-org
//   HCB_COOKIE='...' node scripts/ledger_diff.mjs --file slugs.txt --json out.json
//
// Get the cookie from your browser devtools on a signed-in HCB session (use an
// admin/auditor account so both pages render the same level of detail).

import { readFileSync, writeFileSync } from 'node:fs'

const ALL_FIELDS = [
  'id',
  'type',
  'date',
  'amount',
  'memo',
  'status',
  'tags',
  'receipts',
  'comments',
  'author',
]
const DEFAULT_IGNORE = ['id', 'type']

// Row keys are built by concatenating formatted fields. Joining on a character that
// cannot occur in rendered HTML text keeps the split unambiguous: with a plain join
// {memo: "ab", status: "c"} and {memo: "abc", status: ""} produce the same key and
// get matched to each other.
const SEP = '\u0000'

const USAGE = `
Usage: node scripts/ledger_diff.mjs [options] <slug|event_id> [...]

Options:
  --file <path>        Read slugs from a file (one per line, # comments allowed)
  --base <url>         Base URL            (default: $HCB_BASE or https://hcb.hackclub.com)
  --cookie <string>    Session cookie      (default: $HCB_COOKIE)
  --cookie-file <path> Read the cookie from a file
  --per <n>            Rows per page, 1-200                        (default: 200)
  --max-pages <n>      Safety cap on pages fetched per engine      (default: 100)
  --concurrency <n>    Orgs fetched in parallel                    (default: 4)
  --retries <n>        Attempts per request before giving up       (default: 5)
  --rate <n>           Requests per minute, all orgs combined      (default: 90)
  --delay <ms>         Extra pause between page fetches in an org  (default: 0)
  --ignore <fields>    Comma-separated fields to ignore            (default: ${DEFAULT_IGNORE.join(',')})
                       Available: ${ALL_FIELDS.join(', ')}
  --params <qs>        Extra query string appended to both engines (e.g. 'q=stripe')
  --timeout <ms>       Per-request timeout                         (default: 60000)
  --json <path>        Write the full machine-readable report here
  --quiet              Only print orgs that differ
  --help               Show this

Exits 1 if any org differs, 2 if any org errored.
`.trim()

// ---------------------------------------------------------------- args

function parseArgs(argv) {
  const opts = {
    slugs: [],
    base: process.env.HCB_BASE || 'https://hcb.hackclub.com',
    cookie: process.env.HCB_COOKIE || '',
    per: 200,
    maxPages: 100,
    concurrency: 4,
    retries: 5,
    rate: 90,
    delay: 0,
    ignore: [...DEFAULT_IGNORE],
    params: '',
    timeout: 60_000,
    json: null,
    quiet: false,
  }

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i]
    const next = () => {
      const value = argv[++i]
      if (value === undefined) fail(`${arg} requires a value`)
      return value
    }

    switch (arg) {
      case '--help':
      case '-h':
        console.log(USAGE)
        process.exit(0)
        break
      case '--file':
        opts.slugs.push(...readSlugFile(next()))
        break
      case '--base':
        opts.base = next().replace(/\/+$/, '')
        break
      case '--cookie':
        opts.cookie = next()
        break
      case '--cookie-file':
        opts.cookie = readFileTrimmed(next())
        break
      case '--per':
        opts.per = clamp(parseInt(next(), 10), 1, 200)
        break
      case '--max-pages':
        opts.maxPages = Math.max(1, parseInt(next(), 10))
        break
      case '--concurrency':
        opts.concurrency = Math.max(1, parseInt(next(), 10))
        break
      case '--retries':
        opts.retries = Math.max(1, parseInt(next(), 10))
        break
      case '--rate':
        opts.rate = Math.max(1, parseInt(next(), 10))
        break
      case '--delay':
        opts.delay = Math.max(0, parseInt(next(), 10))
        break
      case '--ignore':
        opts.ignore = next()
          .split(',')
          .map(f => f.trim())
          .filter(Boolean)
        break
      case '--params':
        opts.params = next().replace(/^\?/, '')
        break
      case '--timeout':
        opts.timeout = Math.max(1000, parseInt(next(), 10))
        break
      case '--json':
        opts.json = next()
        break
      case '--quiet':
        opts.quiet = true
        break
      default:
        if (arg.startsWith('-')) fail(`unknown option ${arg}`)
        opts.slugs.push(arg)
    }
  }

  const unknown = opts.ignore.filter(f => !ALL_FIELDS.includes(f))
  if (unknown.length)
    fail(`unknown field(s) in --ignore: ${unknown.join(', ')}`)

  opts.compare = ALL_FIELDS.filter(f => !opts.ignore.includes(f))
  if (!opts.compare.length) fail('--ignore leaves nothing to compare')
  if (!opts.slugs.length) fail('no slugs given\n\n' + USAGE)
  if (!opts.cookie) fail('no session cookie - pass --cookie or set HCB_COOKIE')

  opts.slugs = [...new Set(opts.slugs)]
  return opts
}

function readSlugFile(path) {
  return readFileTrimmed(path)
    .split('\n')
    .map(line => line.replace(/#.*$/, '').trim())
    .filter(Boolean)
}

function readFileTrimmed(path) {
  try {
    return readFileSync(path, 'utf8').trim()
  } catch (error) {
    fail(`could not read ${path}: ${error.message}`)
  }
}

function fail(message) {
  console.error(`ledger_diff: ${message}`)
  process.exit(2)
}

const clamp = (n, lo, hi) => Math.min(hi, Math.max(lo, n))

// ---------------------------------------------------------------- fetching

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms))

const BASE_BACKOFF = 1_000
const MAX_BACKOFF = 60_000

// Jittered, so a pool that got rate limited together doesn't retry in lockstep.
const backoff = attempt =>
  Math.min(MAX_BACKOFF, BASE_BACKOFF * 2 ** attempt * (0.5 + Math.random()))

// HCB throttles exactly these paths at 100 requests per IP per minute (`ledger/ip` in
// config/initializers/rack_attack.rb). Two things make that worth respecting up front
// rather than discovering: rack-attack counts throttled requests too, so retrying inside a
// spent window keeps it spent, and its `Retry-After` header is opt-in and off here, so a
// 429 tells us nothing about when to come back. Both are answered by mirroring its own
// accounting - a fixed window keyed on epoch minutes - and staying just under the limit.
const RATE_PERIOD = 60_000
const windowEndsAt = () => Math.ceil(Date.now() / RATE_PERIOD) * RATE_PERIOD

let windowEnd = 0
let spent = 0

// A 429 is a fact about the whole run, not one request, so the pause is shared: every
// worker waits behind the same gate rather than each finding the wall on its own.
let gateUntil = 0

async function waitForGate() {
  while (gateUntil > Date.now()) await sleep(gateUntil - Date.now())
}

// Returns 0 when another worker had already paused us for at least as long, so a throttle
// that every in-flight worker runs into is reported once rather than once each.
function holdGate(ms) {
  const until = Date.now() + ms
  if (until <= gateUntil) return 0

  gateUntil = until
  return ms
}

// Claims one request against the shared per-minute budget, waiting for the next window
// when this one is used up.
async function reserveSlot(opts) {
  for (;;) {
    await waitForGate()

    const end = windowEndsAt()
    if (end !== windowEnd) {
      windowEnd = end
      spent = 0
    }
    if (spent < opts.rate) {
      spent++
      return
    }
    await sleep(end - Date.now() + 250)
  }
}

// `Retry-After` is either a number of seconds or an HTTP date; honour whichever we get.
// HCB sends neither, so callers need a fallback.
function retryAfter(response) {
  const header = response.headers.get('retry-after')
  if (!header) return null

  const seconds = Number(header)
  if (Number.isFinite(seconds)) return Math.max(0, seconds * 1000)

  const at = Date.parse(header)
  return Number.isFinite(at) ? Math.max(0, at - Date.now()) : null
}

async function fetchPage(url, opts) {
  let lastError
  let throttled = false

  for (let attempt = 0; attempt < opts.retries; attempt++) {
    // After a throttle the gate has already waited exactly as long as it should; only a
    // genuine error needs the extra backoff on top.
    if (attempt && !throttled) await sleep(backoff(attempt - 1))
    throttled = false
    await reserveSlot(opts)

    try {
      const response = await fetch(url, {
        headers: {
          cookie: opts.cookie,
          accept: 'text/html',
          'user-agent': 'hcb-ledger-diff',
        },
        redirect: 'manual',
        signal: AbortSignal.timeout(opts.timeout),
      })

      // 503s from a throttling proxy look the same as a rate limit; back off for both.
      if (response.status === 429 || response.status === 503) {
        lastError = new Error(
          `rate limited (${response.status}) on ${url} after ${attempt + 1} attempt(s)`
        )
        // The window is spent - and the 429 itself was counted against it - so the only
        // useful thing to wait for is the next one. Burn the local budget with it, so
        // workers already past the gate don't spend the new window on stale retries.
        spent = opts.rate
        throttled = true
        const held = holdGate(
          retryAfter(response) ?? windowEndsAt() - Date.now() + 500
        )
        if (held)
          console.error(
            dim(
              `  rate limited, waiting ${(held / 1000).toFixed(1)}s for the window to reset`
            )
          )
        continue
      }
      if (response.status >= 300 && response.status < 400) {
        throw new Error(
          `redirected to ${response.headers.get('location')} - is HCB_COOKIE still valid?`
        )
      }
      if (response.status === 404)
        throw new Error('404 - no such org, or no access with this session')
      if (response.status >= 500) {
        lastError = new Error(`${response.status} from ${url}`)
        continue
      }
      if (!response.ok) throw new Error(`${response.status} from ${url}`)

      return await response.text()
    } catch (error) {
      // Only retry transient failures; a bad cookie or a missing org won't fix itself.
      if (/valid\?|^404/.test(error.message)) throw error
      lastError = error
    }
  }

  throw lastError
}

async function fetchEngine(slug, engine, opts) {
  const path = engine === 'old' ? 'transactions_list' : 'ledger'
  const rows = []

  for (let page = 1; page <= opts.maxPages; page++) {
    const query = new URLSearchParams({
      page: String(page),
      per: String(opts.per),
    })
    const extra = opts.params ? `&${opts.params}` : ''
    const html = await fetchPage(
      `${opts.base}/${encodeURIComponent(slug)}/${path}?${query}${extra}`,
      opts
    )
    const pageRows = extractRows(html)

    if (!pageRows.length) return rows
    rows.push(...pageRows)
    if (opts.delay) await sleep(opts.delay)
  }

  // Falling out of the loop means the cap was reached with rows still arriving, so the
  // tail of this engine is missing. Diffing a truncated engine against a complete one
  // invents a missing/extra row for everything past the cut, so refuse rather than
  // report a diff that is mostly an artefact of the cap.
  throw new Error(
    `${engine} engine still had rows at --max-pages (${opts.maxPages} x ${opts.per} = ` +
      `${opts.maxPages * opts.per} rows); raise --max-pages`
  )
}

// ---------------------------------------------------------------- html parsing

const VOID_TAGS = new Set([
  'area',
  'base',
  'br',
  'col',
  'embed',
  'hr',
  'img',
  'input',
  'link',
  'meta',
  'param',
  'source',
  'track',
  'wbr',
])
const RAW_TEXT_TAGS = new Set(['script', 'style', 'template'])
// Tags an unclosed sibling implicitly closes, so one stray tag can't swallow the table.
const IMPLICIT_CLOSE = {
  td: ['td', 'th'],
  th: ['td', 'th'],
  tr: ['td', 'th', 'tr'],
  li: ['li'],
  p: ['p'],
  option: ['option'],
}

const TOKEN =
  /<!--[\s\S]*?-->|<!\[CDATA\[[\s\S]*?\]\]>|<![^>]*>|<\/([a-zA-Z][^\s>]*)\s*>|<([a-zA-Z][^\s/>]*)((?:"[^"]*"|'[^']*'|[^>"'])*?)(\/?)>/g
const ATTR = /([^\s=/>]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+)))?/g

function parseHTML(html) {
  const root = { tag: '#root', attrs: {}, children: [] }
  const stack = [root]
  const push = node => stack[stack.length - 1].children.push(node)

  TOKEN.lastIndex = 0
  let cursor = 0
  let match

  while ((match = TOKEN.exec(html))) {
    if (match.index > cursor) push({ text: html.slice(cursor, match.index) })
    cursor = TOKEN.lastIndex

    const [token, closeTag, openTag, rawAttrs, selfClosing] = match
    if (token.startsWith('<!')) continue

    if (closeTag) {
      const tag = closeTag.toLowerCase()
      for (let i = stack.length - 1; i > 0; i--) {
        if (stack[i].tag === tag) {
          stack.length = i
          break
        }
      }
      continue
    }

    const tag = openTag.toLowerCase()
    const closes = IMPLICIT_CLOSE[tag]
    if (closes) {
      while (stack.length > 1 && closes.includes(stack[stack.length - 1].tag))
        stack.pop()
    }

    const node = { tag, attrs: parseAttrs(rawAttrs), children: [] }
    push(node)

    if (selfClosing || VOID_TAGS.has(tag)) continue

    if (RAW_TEXT_TAGS.has(tag)) {
      const end = html.slice(cursor).search(new RegExp(`</${tag}\\s*>`, 'i'))
      if (end === -1) break
      cursor += end + tag.length + 3
      TOKEN.lastIndex = cursor
      continue
    }

    stack.push(node)
  }

  if (cursor < html.length) push({ text: html.slice(cursor) })
  return root
}

function parseAttrs(raw) {
  const attrs = {}
  if (!raw) return attrs

  ATTR.lastIndex = 0
  let match
  while ((match = ATTR.exec(raw))) {
    attrs[match[1].toLowerCase()] = decodeEntities(
      match[2] ?? match[3] ?? match[4] ?? ''
    )
  }
  return attrs
}

const ENTITIES = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ' }

function decodeEntities(text) {
  return text.replace(/&(#x?[0-9a-fA-F]+|[a-zA-Z]+);/g, (whole, name) => {
    if (ENTITIES[name]) return ENTITIES[name]
    if (name[0] === '#') {
      const code =
        name[1] === 'x' || name[1] === 'X'
          ? parseInt(name.slice(2), 16)
          : parseInt(name.slice(1), 10)
      return Number.isFinite(code) ? String.fromCodePoint(code) : whole
    }
    return whole
  })
}

const classesOf = node => (node.attrs?.class || '').split(/\s+/).filter(Boolean)
const hasClass = (node, name) => classesOf(node).includes(name)
const hasAnyClass = (node, names) =>
  classesOf(node).some(c => names.includes(c))

function findAll(node, predicate, found = []) {
  for (const child of node.children || []) {
    if (child.tag) {
      if (predicate(child)) found.push(child)
      findAll(child, predicate, found)
    }
  }
  return found
}

// Text content, minus any subtree the caller wants dropped (badges, menus, forms...).
function textOf(node, skip = () => false) {
  if (node.text !== undefined) return node.text
  if (node.tag && skip(node)) return ''

  let text = ''
  for (const child of node.children || []) text += textOf(child, skip)
  return text
}

const squish = text => decodeEntities(text).replace(/\s+/g, ' ').trim()

// ---------------------------------------------------------------- row extraction

const DATE_RE = /^([A-Z][a-z]{2})\s+(\d{1,2}),\s+(\d{4})$/
const MONEY_RE = /^[-+−]?\$[\d,]+(\.\d{2})?$/
const MONTHS = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
]
// Subtrees that are chrome, not content: tag pills, count badges, the add-tag menu,
// the inline rename form, upload buttons.
const CHROME_CLASSES = [
  'badge',
  'list-badge',
  'tx-tag',
  'add-tag-badge',
  'menu__content',
  'renaming',
  'suggested_tag',
]
const CHROME_TAGS = ['form', 'button', 'script', 'template', 'svg']

function extractRows(html) {
  return findAll(
    parseHTML(html),
    node => node.tag === 'tr' && hasClass(node, 'transaction')
  ).map(parseRow)
}

function parseRow(tr) {
  const cells = tr.children.filter(child => child.tag === 'td')
  // A selectable row renders a second `transaction__icon` cell (the checkmark), so take
  // the labelled one as the type and keep every icon cell out of the positional search.
  const iconCells = cells.filter(cell => hasClass(cell, 'transaction__icon'))
  const iconCell = iconCells.find(firstAriaLabel) || iconCells[0]
  const memoCell = cells.find(cell => hasClass(cell, 'transaction__memo'))
  const plainCells = cells.filter(
    cell => !iconCells.includes(cell) && cell !== memoCell
  )

  const dateCell = plainCells.find(cell => DATE_RE.test(squish(textOf(cell))))
  // The amount is the first money cell; a running-balance column, when present, follows it.
  const amountCell = plainCells.find(
    cell => cell !== dateCell && MONEY_RE.test(squish(textOf(cell)))
  )

  return {
    id: tr.attrs.id || idFromLinks(tr),
    type: iconCell ? firstAriaLabel(iconCell) : null,
    date: dateCell ? isoDate(squish(textOf(dateCell))) : null,
    amount: amountCell
      ? parseMoney(squish(textOf(amountCell)))
      : rawAmount(plainCells, dateCell),
    memo: memoCell ? squish(textOf(memoCell, isChrome)) : null,
    status: memoCell ? statusOf(memoCell) : null,
    tags: findAll(
      tr,
      node => node.attrs['data-tag'] && hasClass(node, 'tx-tag')
    )
      .map(node => node.attrs['data-tag'])
      .sort((a, b) => Number(a) - Number(b)),
    receipts: countBadge(tr, 'receipt'),
    comments: countBadge(tr, 'comment'),
    author: authorOf(cells),
  }
}

const isChrome = node =>
  CHROME_TAGS.includes(node.tag) ||
  hasAnyClass(node, CHROME_CLASSES) ||
  'hidden' in node.attrs

function idFromLinks(tr) {
  for (const anchor of findAll(
    tr,
    node => node.tag === 'a' && node.attrs.href
  )) {
    const match = anchor.attrs.href.match(
      /\/(?:hcb|transactions)\/([A-Za-z0-9_-]+)/
    )
    if (match) return match[1]
  }
  return null
}

function firstAriaLabel(node) {
  if (node.attrs?.['aria-label'])
    return squish(node.attrs['aria-label']) || null
  const labelled = findAll(node, child => child.attrs['aria-label'])
  return labelled.length
    ? squish(labelled[0].attrs['aria-label']) || null
    : null
}

function isoDate(text) {
  const match = text.match(DATE_RE)
  if (!match) return text

  const month = MONTHS.indexOf(match[1])
  if (month === -1) return text
  return `${match[3]}-${String(month + 1).padStart(2, '0')}-${match[2].padStart(2, '0')}`
}

// Returns cents, so "$1,234.56" and "-$1,234.56" compare independently of formatting.
function parseMoney(text) {
  const negative = /^[-−]/.test(text)
  const digits = text.replace(/[^\d.]/g, '')
  if (!digits) return text

  const cents = Math.round(parseFloat(digits) * 100)
  return Number.isFinite(cents) ? (negative ? -cents : cents) : text
}

// Amounts can be redacted for non-organizers; keep whatever was rendered.
function rawAmount(plainCells, dateCell) {
  const cell = plainCells.find(c => c !== dateCell && squish(textOf(c)))
  return cell ? squish(textOf(cell)) : null
}

function statusOf(memoCell) {
  const badges = findAll(
    memoCell,
    node =>
      hasClass(node, 'badge') &&
      !hasAnyClass(node, ['tx-tag', 'list-badge', 'add-tag-badge'])
  )
  const text = badges
    .map(badge => squish(textOf(badge)))
    .filter(Boolean)
    .join(', ')
  return text || null
}

function countBadge(tr, noun) {
  const pattern = new RegExp(`^(\\d+)\\s+${noun}s?$`, 'i')
  for (const badge of findAll(
    tr,
    node => hasClass(node, 'list-badge') && node.attrs['aria-label']
  )) {
    const match = squish(badge.attrs['aria-label']).match(pattern)
    if (match) return Number(match[1])
  }
  return 0 // `list_badge_for` omits the badge entirely when it's optional and zero.
}

// The author column is the row's trailing cell. Every cell before it - icon, memo, date,
// amount, running balance - is identified and dropped rather than scanned, so an author
// cell the engine left empty reports null instead of the scan spilling into a neighbour:
// `redacted_amount` renders `aria-label="Hidden for security"`, which a backwards scan
// would otherwise read as somebody's name. The new ledger renders an empty `<td>`
// whenever `item.author` is nil, so this is the common case, not the edge one.
function authorOf(cells) {
  const candidates = cells.filter(cell => {
    if (
      hasClass(cell, 'transaction__memo') ||
      hasClass(cell, 'transaction__icon')
    )
      return false

    const text = squish(textOf(cell))
    return !DATE_RE.test(text) && !MONEY_RE.test(text)
  })

  const cell = candidates[candidates.length - 1]
  if (!cell) return null

  const label = firstAriaLabel(cell)
  if (label) return label

  const avatar = findAll(cell, node => node.tag === 'img' && node.attrs.alt)
  return avatar.length ? squish(avatar[0].attrs.alt) : null
}

// ---------------------------------------------------------------- diffing

function diffRows(oldRows, newRows, compare) {
  const strictKey = row => compare.map(field => format(row[field])).join(SEP)
  // Date + amount is the most stable pair across engines, so it's what we use to
  // recognise "the same transaction, rendered differently" instead of an add/remove pair.
  const looseKey = row => `${row.date}${SEP}${format(row.amount)}`

  const matchedNew = new Array(newRows.length).fill(false)
  const matchedOld = new Array(oldRows.length).fill(false)

  const byStrict = bucket(newRows, strictKey, () => true)
  oldRows.forEach((row, i) => {
    const queue = byStrict.get(strictKey(row))
    if (queue?.length) {
      matchedOld[i] = true
      matchedNew[queue.shift()] = true
    }
  })

  const byLoose = bucket(newRows, looseKey, (_, i) => !matchedNew[i])
  const changed = []
  oldRows.forEach((row, i) => {
    if (matchedOld[i]) return

    const queue = byLoose.get(looseKey(row))
    if (!queue?.length) return

    const j = queue.shift()
    matchedOld[i] = true
    matchedNew[j] = true

    const fields = {}
    for (const field of compare) {
      const before = format(row[field])
      const after = format(newRows[j][field])
      if (before !== after)
        fields[field] = { old: row[field], new: newRows[j][field] }
    }
    changed.push({
      date: row.date,
      amount: row.amount,
      oldId: row.id,
      newId: newRows[j].id,
      fields,
    })
  })

  const missing = oldRows.filter((_, i) => !matchedOld[i])
  const extra = newRows.filter((_, i) => !matchedNew[i])

  return {
    counts: {
      old: oldRows.length,
      new: newRows.length,
      matched: matchedOld.filter(Boolean).length - changed.length,
      changed: changed.length,
      missing: missing.length,
      extra: extra.length,
    },
    changed,
    missing,
    extra,
    order: diffOrder(oldRows.map(looseKey), newRows.map(looseKey)),
  }
}

// Index queues keyed by `key`, so duplicate rows are matched one-for-one rather than collapsed.
function bucket(rows, key, include) {
  const map = new Map()
  rows.forEach((row, index) => {
    if (!include(row, index)) return

    const list = map.get(key(row))
    if (list) list.push(index)
    else map.set(key(row), [index])
  })
  return map
}

// Rows can all be present but sequenced differently - that's a real regression for a
// ledger, so report where the two orderings first part ways.
function diffOrder(oldKeys, newKeys) {
  const readable = key => key.replace(SEP, ' / ')
  const length = Math.min(oldKeys.length, newKeys.length)
  for (let i = 0; i < length; i++) {
    if (oldKeys[i] !== newKeys[i]) {
      return {
        divergesAt: i,
        old: readable(oldKeys[i]),
        new: readable(newKeys[i]),
      }
    }
  }
  return oldKeys.length === newKeys.length
    ? null
    : { divergesAt: length, old: null, new: null }
}

function format(value) {
  if (value === null || value === undefined) return ''
  if (Array.isArray(value)) return value.join(',')
  return String(value)
}

// ---------------------------------------------------------------- reporting

const TTY = process.stdout.isTTY
const ESC = String.fromCharCode(27)
const color = (code, text) => (TTY ? `${ESC}[${code}m${text}${ESC}[0m` : text)
const red = t => color(31, t)
const green = t => color(32, t)
const yellow = t => color(33, t)
const dim = t => color(2, t)
const bold = t => color(1, t)

function money(cents) {
  const sign = cents < 0 ? '-' : ''
  return `${sign}$${(Math.abs(cents) / 100).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ',')}`
}

const amountOf = row =>
  typeof row.amount === 'number' ? money(row.amount) : format(row.amount)

function describe(row) {
  return `${row.date ?? '?'}  ${amountOf(row).padStart(12)}  ${JSON.stringify(row.memo ?? '')}${row.id ? dim(`  (${row.id})`) : ''}`
}

function report(result, opts) {
  const { slug, error, diff } = result

  if (error) {
    console.log(`${bold(slug)}  ${red('error')}  ${error}`)
    return
  }

  const { counts } = diff
  const clean =
    !counts.changed && !counts.missing && !counts.extra && !diff.order
  const headline = `${bold(slug)}  ${dim(`old=${counts.old} new=${counts.new}`)}`

  if (clean) {
    if (!opts.quiet) console.log(`${headline}  ${green('identical')}`)
    return
  }

  const summary = [
    counts.missing ? red(`${counts.missing} missing in new`) : null,
    counts.extra ? red(`${counts.extra} only in new`) : null,
    counts.changed ? yellow(`${counts.changed} changed`) : null,
    diff.order ? yellow(`order diverges at #${diff.order.divergesAt}`) : null,
  ].filter(Boolean)

  console.log(`${headline}  ${summary.join(', ')}`)

  for (const row of diff.missing) console.log(`  ${red('-')} ${describe(row)}`)
  for (const row of diff.extra) console.log(`  ${green('+')} ${describe(row)}`)

  for (const change of diff.changed) {
    console.log(
      `  ${yellow('~')} ${change.date ?? '?'}  ${amountOf(change).padStart(12)}  ${dim(`${change.oldId ?? '?'} -> ${change.newId ?? '?'}`)}`
    )
    for (const [field, { old: before, new: after }] of Object.entries(
      change.fields
    )) {
      console.log(
        `      ${field.padEnd(9)} old=${JSON.stringify(format(before))}  new=${JSON.stringify(format(after))}`
      )
    }
  }

  if (diff.order?.old) {
    console.log(
      `  ${yellow('~')} order: position ${diff.order.divergesAt} is ${dim(diff.order.old)} in old, ${dim(diff.order.new)} in new`
    )
  }
}

// ---------------------------------------------------------------- main

async function run(slug, opts) {
  try {
    const [oldRows, newRows] = await Promise.all([
      fetchEngine(slug, 'old', opts),
      fetchEngine(slug, 'new', opts),
    ])
    return { slug, error: null, diff: diffRows(oldRows, newRows, opts.compare) }
  } catch (error) {
    return { slug, error: error.message, diff: null }
  }
}

async function pool(items, limit, worker) {
  const results = new Array(items.length)
  let cursor = 0

  await Promise.all(
    Array.from({ length: Math.min(limit, items.length) }, async () => {
      while (cursor < items.length) {
        const index = cursor++
        results[index] = await worker(items[index])
      }
    })
  )

  return results
}

async function main() {
  const opts = parseArgs(process.argv.slice(2))

  console.log(
    dim(
      `${opts.base}  ${opts.slugs.length} org(s)  ${opts.rate}/min  comparing: ${opts.compare.join(', ')}  ignoring: ${opts.ignore.join(', ') || 'nothing'}`
    )
  )

  const results = await pool(opts.slugs, opts.concurrency, slug =>
    run(slug, opts)
  )
  for (const result of results) report(result, opts)

  const errored = results.filter(r => r.error)
  const differing = results.filter(
    r =>
      r.diff &&
      (r.diff.counts.changed ||
        r.diff.counts.missing ||
        r.diff.counts.extra ||
        r.diff.order)
  )

  console.log(
    `\n${bold('summary')}  ${results.length - errored.length - differing.length} identical, ` +
      `${differing.length} differing, ${errored.length} errored`
  )

  if (opts.json) {
    writeFileSync(
      opts.json,
      JSON.stringify(
        {
          base: opts.base,
          generatedAt: new Date().toISOString(),
          compare: opts.compare,
          results,
        },
        null,
        2
      )
    )
    console.log(dim(`wrote ${opts.json}`))
  }

  process.exit(errored.length ? 2 : differing.length ? 1 : 0)
}

main()
