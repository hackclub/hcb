# restore previous theme setting
$(document).ready ->
  BK.s('toggle_theme').find('svg').toggle() if localStorage.getItem('dark') is 'true'
  BK.styleDark(true) if localStorage.getItem('dark') is 'true'

$(document).on 'turbolinks:load', ->
  $('[data-behavior~=toggle_theme]').on 'click', ->
    BK.toggleDark()
  
  $('[data-behavior~=select_content]').on 'click', (e) ->
    e.target.select()

  window.updateChangelogTooltip = ->
    target = $('[data-behavior~=toggle_changelog]')
    if $('#HW_frame_cont.HW_visible').length > 0
      target.attr 'aria-label', ''
    else
      target.attr 'aria-label', 'Show changes'

  $(document).on 'mouseover', '[data-behavior~=toggle_changelog]', updateChangelogTooltip

  hankIndex = 0
  $(document).on 'keydown', (e) ->
    if e.originalEvent.key == 'hank'[hankIndex]
      hankIndex++
      if hankIndex == 4
        $('[name="header-logo"]').hide()
        $('[name="alternative-logo"]').show()
    else
      hankIndex = 0

  $(document).on 'click', '[data-behavior~=flash]', ->
    $(this).fadeOut 'medium'

  $(document).on 'click', '[data-behavior~=modal_trigger]', ->
    BK.s('modal', '#' + $(this).data('modal')).modal()
    this.blur()

  $(document).on 'click', '[data-behavior~=row_expand_trigger]', ->
    button = $(this)
    id = button.data 'id'
    targets = BK.s('expandable_row').filter("[data-id=#{id}]")
    parent = BK.s('parent_expandable_row').filter("[data-id=#{id}]")
    expanded = button.data 'expanded'
    if expanded
      targets.removeClass('is-expanded')
      parent.removeClass('is-expanded')
      button.text 'Expand'
      button.data 'expanded', false
    else
      targets.addClass('is-expanded')
      parent.addClass('is-expanded')
      button.text 'Retract'
      button.data 'expanded', true

  $(document).on 'keyup', 'action', (e) ->
    $(e.target).click() if e.keyCode is 13

  $(document).on 'submit', '[data-behavior~=login]', ->
    val = $('input[name=email]').val()
    localStorage.setItem 'login_email', val

  if BK.thereIs 'login'
    if email = localStorage.getItem 'login_email'
      BK.s('login').find('input[type=email]').val email

  $(document).on 'change', '[name="invoice[sponsor]"]', (e) ->
    sponsor = $(e.target).children('option:selected').data 'json'
    sponsor ||= {}

    if sponsor.id
      $('[data-behavior~=sponsor_update_warning]').slideDown 'fast'
    else
      $('[data-behavior~=sponsor_update_warning]').slideUp 'fast'

    fields = [
      'name',
      'contact_email',
      'address_line1',
      'address_line2',
      'address_city',
      'address_state',
      'address_postal_code',
      'id'
    ]

    fields.forEach (field) ->
      $("input#invoice_sponsor_attributes_#{field}").val sponsor[field]

  $(document).on 'change', '[name="check[lob_address]"]', (e) ->
    lob_address = $(e.target).children('option:selected').data 'json'
    lob_address ||= {}

    if lob_address.id
      $('[data-behavior~=lob_address_update_warning]').slideDown 'fast'
    else
      $('[data-behavior~=lob_address_update_warning]').slideUp 'fast'

    fields = [
      'name',
      'address1',
      'address2',
      'city',
      'state',
      'zip',
      'id'
    ]

    fields.forEach (field) ->
      $("input#check_lob_address_attributes_#{field}").val(lob_address[field]).change()

  updateAmountPreview = ->
    amount = $('[name="invoice[item_amount]"]').val()
    previousAmount = BK.s('amount-preview').data('amount') || 0
    if amount == previousAmount
      return
    if amount > 0
      feePercent = BK.s('amount-preview').data 'fee'
      lFeePercent = (feePercent * 100).toFixed 1
      lAmount = BK.money amount * 100
      feeAmount = BK.money feePercent * amount * 100
      revenue = BK.money (1 - feePercent) * amount * 100
      BK.s('amount-preview').text "#{lAmount} - #{feeAmount} (#{lFeePercent}% Bank fee) = #{revenue}"
      BK.s('amount-preview').show()
      BK.s('amount-preview').data 'amount', amount
    else
      BK.s('amount-preview').hide()
      BK.s('amount-preview').data 'amount', 0

  $(document).on 'keyup', '[name="invoice[item_amount]"]', ->
    updateAmountPreview()
  $(document).on 'change', '[name="invoice[item_amount]"]', ->
    updateAmountPreview()

  $(document).on 'keydown', '[data-behavior~=autosize]', ->
    t = this
    setTimeout (->
      $(t).attr { rows: Math.floor(t.scrollHeight / 28) }
      $(t).css { height: 'auto' }
    ), 0

  # Popover menus
  BK.openMenuSelector =  '[data-behavior~=menu_toggle][aria-expanded=true]'
  BK.toggleMenu = (m) ->
    $(m).find('[data-behavior~=menu_content]').slideToggle 100
    o = $(m).attr('aria-expanded') is 'true'
    $(m).attr 'aria-expanded', !o

  $(document).on 'click', (e) ->
    o = $(BK.openMenuSelector)
    c = $(e.target).closest('[data-behavior~=menu_toggle]')
    if o.length > 0 or c.length > 0
      BK.toggleMenu `o.length > 0 ? o : c`
    e.stopImmediatePropagation()
    return
  $(document).keydown (e) ->
    # Close popover menus on esc
    if e.keyCode is 27 and $(BK.openMenuSelector).length > 0
      BK.toggleMenu $(BK.openMenuSelector)

  tiltElement = $('[data-behavior~=hover_tilt]')
  enableTilt = ->
    tiltElement.tilt
      maxTilt: 15
      speed: 400
      perspective: 1500
      glare: true
      maxGlare: .25
      scale: 1.0625
  disableTilt = ->
    tiltElement.tilt.destroy.call(tiltElement)
  setTilt = ->
    if window.matchMedia('(prefers-reduced-motion: reduce)').matches
      disableTilt()
    else
      enableTilt()
  setTilt()
  window.matchMedia('(prefers-reduced-motion: reduce)').addListener -> 
    setTilt()

