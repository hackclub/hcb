function loadTextExpander() {
  document.querySelectorAll('text-expander').forEach((expander) => {
    expander.addEventListener('text-expander-change', function(event) {
      const {key, provide, text} = event.detail
      if (key !== '@') return
    
      const suggestions = document.querySelector('.mention-suggestions').cloneNode(true)
      suggestions.hidden = false
      count = 0
      for (const suggestion of suggestions.children) {
        if (!suggestion.dataset.search.toLowerCase().match(text.toLowerCase())) {
          suggestion.classList.add("display-none")
        } else {
          suggestion.classList.remove("display-none")
          count++
        }
      }
      provide(Promise.resolve({matched: count > 0, fragment: suggestions}))
    })
    
    expander.addEventListener('text-expander-value', function(event) {
      const {key, item}  = event.detail
      if (key === '@') {
        event.detail.value = item.getAttribute('data-value')
      }
    })
    
    expander.addEventListener('text-expander-activate', function(event) {
      const popover = expander.querySelector('.mention-suggestions[popover]')
      if (popover) popover.showPopover()
    })
  });
}

document.addEventListener("turbo:load", loadTextExpander)
