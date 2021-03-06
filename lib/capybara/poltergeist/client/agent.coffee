# This is injected into each page that is loaded

class PoltergeistAgent
  constructor: ->
    @elements = []
    @nodes    = {}

  externalCall: (name, args) ->
    try
      { value: this[name].apply(this, args) }
    catch error
      { error: { message: error.toString(), stack: error.stack } }

  @stringify: (object) ->
    try
      JSON.stringify object, (key, value) ->
        if Array.isArray(this[key])
          return this[key]
        else
          return value
    catch error
      if error instanceof TypeError
        '"(cyclic structure)"'
      else
        throw error

  currentUrl: ->
    window.location.toString()

  find: (method, selector, within = document) ->
    if method == "xpath"
      xpath   = document.evaluate(selector, within, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null)
      results = (xpath.snapshotItem(i) for i in [0...xpath.snapshotLength])
    else
      results = within.querySelectorAll(selector)

    this.register(el) for el in results

  register: (element) ->
    @elements.push(element)
    @elements.length - 1

  documentSize: ->
    height: document.documentElement.scrollHeight,
    width:  document.documentElement.scrollWidth

  get: (id) ->
    @nodes[id] or= new PoltergeistAgent.Node(this, @elements[id])

  nodeCall: (id, name, args) ->
    node = this.get(id)
    throw new PoltergeistAgent.ObsoleteNode if node.isObsolete()
    node[name].apply(node, args)

  beforeUpload: (id) ->
    this.get(id).setAttribute('_poltergeist_selected', '')

  afterUpload: (id) ->
    this.get(id).removeAttribute('_poltergeist_selected')

class PoltergeistAgent.ObsoleteNode
  toString: -> "PoltergeistAgent.ObsoleteNode"

class PoltergeistAgent.Node
  @EVENTS = {
    FOCUS: ['blur', 'focus', 'focusin', 'focusout'],
    MOUSE: ['click', 'dblclick', 'mousedown', 'mouseenter', 'mouseleave', 'mousemove',
            'mouseover', 'mouseout', 'mouseup']
  }

  constructor: (@agent, @element) ->

  parentId: ->
    @agent.register(@element.parentNode)

  find: (method, selector) ->
    @agent.find(method, selector, @element)

  isObsolete: ->
    obsolete = (element) =>
      if element.parentNode?
        if element.parentNode == document
          false
        else
          obsolete element.parentNode
      else
        true
    obsolete @element

  changed: ->
    event = document.createEvent('HTMLEvents')
    event.initEvent('change', true, false)
    @element.dispatchEvent(event)

  insideBody: ->
    @element == document.body ||
    document.evaluate('ancestor::body', @element, null, XPathResult.BOOLEAN_TYPE, null).booleanValue

  allText: ->
    @element.textContent

  visibleText: ->
    if @element.nodeName == "TEXTAREA"
      @element.textContent
    else
      @element.innerText

  getAttribute: (name) ->
    if name == 'checked' || name == 'selected'
      @element[name]
    else
      @element.getAttribute(name)

  scrollIntoView: ->
    @element.scrollIntoViewIfNeeded()

  value: ->
    if @element.tagName == 'SELECT' && @element.multiple
      option.value for option in @element.children when option.selected
    else
      @element.value

  isMultiple: ->
    @element.multiple

  setAttribute: (name, value) ->
    @element.setAttribute(name, value)

  removeAttribute: (name) ->
    @element.removeAttribute(name)

  select: (value) ->
    if value == false && !@element.parentNode.multiple
      false
    else
      @element.selected = value
      this.changed()
      true

  tagName: ->
    @element.tagName

  isVisible: (element) ->
    element = @element unless element

    if window.getComputedStyle(element).display == 'none'
      false
    else if element.parentElement
      this.isVisible element.parentElement
    else
      true

  frameOffset: ->
    win    = window
    offset = { top: 0, left: 0 }

    while win.frameElement
      rect = window.frameElement.getClientRects()[0]
      win  = win.parent

      offset.top  += rect.top
      offset.left += rect.left

    offset

  position: ->
    rect = @element.getClientRects()[0]
    throw new PoltergeistAgent.ObsoleteNode unless rect
    frameOffset = this.frameOffset()

    pos = {
      top:    rect.top    + frameOffset.top,
      right:  rect.right  + frameOffset.left,
      left:   rect.left   + frameOffset.left,
      bottom: rect.bottom + frameOffset.top,
      width:  rect.width,
      height: rect.height
    }

    pos

  trigger: (name) ->
    if Node.EVENTS.MOUSE.indexOf(name) != -1
      event = document.createEvent('MouseEvent')
      event.initMouseEvent(
        name, true, true, window, 0, 0, 0, 0, 0,
        false, false, false, false, 0, null
      )
    else if Node.EVENTS.FOCUS.indexOf(name) != -1
      event = document.createEvent('HTMLEvents')
      event.initEvent(name, true, true)
    else
      throw "Unknown event"

    @element.dispatchEvent(event)

  focusAndHighlight: ->
    @element.focus()
    @element.select()

  blur: ->
    @element.blur()

  mouseEventTest: (x, y) ->
    frameOffset = this.frameOffset()

    x -= frameOffset.left
    y -= frameOffset.top

    el = origEl = document.elementFromPoint(x, y)

    while el
      if el == @element
        return { status: 'success' }
      else
        el = el.parentNode

    { status: 'failure', selector: origEl && this.getSelector(origEl) }

  getSelector: (el) ->
    selector = if el.tagName != 'HTML' then this.getSelector(el.parentNode) + ' ' else ''
    selector += el.tagName.toLowerCase()
    selector += "##{el.id}" if el.id
    for className in el.classList
      selector += ".#{className}"
    selector

  isDOMEqual: (other_id) ->
    @element == @agent.get(other_id).element

window.__poltergeist = new PoltergeistAgent

document.addEventListener(
  'DOMContentLoaded',
  -> console.log('__DOMContentLoaded')
)

window.confirm = (message) -> true
window.prompt  = (message, _default) -> _default or null
