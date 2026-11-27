// Back and Forward between the popover's own history entries are the popover's
// to handle. Turbo would re-render the page for them, or snapshot it and close
// every modal at once, so this listener has to run first: it's imported before
// anything that starts Turbo. Entries from other pages are left to Turbo.
addEventListener('popstate', event => {
  const popover = document.getElementById('shared_popover')
  if (
    !popover ||
    typeof event.state?.popover !== 'boolean' ||
    event.state.turbo?.restorationIdentifier !==
      popover.dataset.popoverPageValue ||
    // Between two entries without it open (a filtered ledger's, say), the page
    // itself changed, so Turbo has to render it
    ((!popover.open || 'closing' in popover.dataset) && !event.state.popover)
  )
    return

  event.stopImmediatePropagation()
  popover.dispatchEvent(
    new CustomEvent('popover:popstate', { detail: event.state })
  )
})
