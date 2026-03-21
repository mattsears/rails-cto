import { StringRewriter } from "@herb-tools/rewriter"

/**
 * Vertically aligns HTML attributes when an element has two or more.
 * Wraps long attribute values (like class lists) aligned to the opening quote.
 *
 * Before:
 *   <div class="flex" data-controller="toggle" id="main">
 *
 * After:
 *   <div class="flex"
 *        data-controller="toggle"
 *        id="main">
 */
export default class AlignAttributes extends StringRewriter {
  get name() { return "align-attributes" }
  get description() { return "Vertically aligns HTML attributes when an element has two or more" }

  maxLineLength = 100

  async initialize(context) {}

  rewrite(content, context) {
    // Collapse dangling > or /> onto the previous line
    content = content.replace(/\n[ \t]*>/g, ">")
    content = content.replace(/\n[ \t]*\/>/g, " />")

    let result = ""
    let pos = 0

    while (pos < content.length) {
      const tagStart = this.findNextOpenTag(content, pos)

      if (tagStart === -1) {
        result += content.slice(pos)
        break
      }

      result += content.slice(pos, tagStart)

      const tag = this.parseTag(content, tagStart)

      if (tag && tag.attributes.length > 1) {
        result += this.formatAligned(tag, content)
      } else if (tag && tag.attributes.length === 1) {
        result += this.formatInline(tag, content)
      } else if (tag) {
        result += content.slice(tagStart, tag.end)
      } else {
        result += content[tagStart]
        pos = tagStart + 1
        continue
      }

      pos = tag.end
    }

    return result
  }

  // Finds the next HTML opening tag (skips closing tags, comments, and ERB)
  findNextOpenTag(content, from) {
    for (let i = from; i < content.length; i++) {
      if (
        content[i] === "<" &&
        i + 1 < content.length &&
        content[i + 1] !== "/" &&
        content[i + 1] !== "!" &&
        content[i + 1] !== "%" &&
        /[a-zA-Z]/.test(content[i + 1])
      ) {
        return i
      }
    }
    return -1
  }

  // Parses a tag starting at `start`, returning tag name, attributes, and end position
  parseTag(content, start) {
    let pos = start + 1

    // Read tag name
    let tagName = ""
    while (pos < content.length && /[a-zA-Z0-9_:-]/.test(content[pos])) {
      tagName += content[pos]
      pos++
    }

    if (!tagName) return null

    const attributes = []
    let currentAttr = ""

    while (pos < content.length) {
      const char = content[pos]

      // End of tag
      if (char === ">") {
        if (currentAttr.trim()) attributes.push(currentAttr.trim())
        return {
          start, end: pos + 1, tagName, attributes, selfClosing: false
        }
      }

      // Self-closing
      if (char === "/" && pos + 1 < content.length && content[pos + 1] === ">") {
        if (currentAttr.trim()) attributes.push(currentAttr.trim())
        return {
          start, end: pos + 2, tagName, attributes, selfClosing: true
        }
      }

      // ERB expression within the tag
      if (char === "<" && pos + 1 < content.length && content[pos + 1] === "%") {
        const erbEnd = content.indexOf("%>", pos + 2)
        if (erbEnd === -1) return null
        currentAttr += content.slice(pos, erbEnd + 2)
        pos = erbEnd + 2
        continue
      }

      // Quoted string (handles ERB inside quotes)
      if (char === '"' || char === "'") {
        const closeQuote = this.findCloseQuote(content, pos)
        if (closeQuote === -1) return null
        currentAttr += content.slice(pos, closeQuote + 1)
        pos = closeQuote + 1
        continue
      }

      // Whitespace separates attributes
      if (/\s/.test(char)) {
        if (currentAttr.trim()) {
          attributes.push(currentAttr.trim())
          currentAttr = ""
        }
        pos++
        continue
      }

      currentAttr += char
      pos++
    }

    return null
  }

  // Finds the closing quote, handling ERB expressions inside quoted values
  findCloseQuote(content, start) {
    const quote = content[start]
    let pos = start + 1

    while (pos < content.length) {
      if (content[pos] === "<" && pos + 1 < content.length && content[pos + 1] === "%") {
        const erbEnd = content.indexOf("%>", pos + 2)
        if (erbEnd === -1) return -1
        pos = erbEnd + 2
        continue
      }

      if (content[pos] === quote) return pos

      pos++
    }

    return -1
  }

  // Collapses a single-attribute tag onto one line, wrapping if needed
  formatInline(tag, content) {
    const { tagName, attributes, selfClosing, start } = tag
    const closing = selfClosing ? " />" : ">"
    const col = this.columnOf(content, start)
    const attrCol = col + 1 + tagName.length + 1

    const wrapped = this.wrapAttribute(attributes[0], attrCol)
    return "<" + tagName + " " + wrapped + closing
  }

  // Formats a tag with attributes vertically aligned, wrapping long values
  formatAligned(tag, content) {
    const { tagName, attributes, selfClosing, start } = tag
    const closing = selfClosing ? " />" : ">"
    const col = this.columnOf(content, start)
    const attrCol = col + 1 + tagName.length + 1
    const alignPad = " ".repeat(attrCol)

    let result = "<" + tagName + " " + this.wrapAttribute(attributes[0], attrCol) + "\n"
    for (let j = 1; j < attributes.length; j++) {
      const isLast = j === attributes.length - 1
      result += alignPad + this.wrapAttribute(attributes[j], attrCol)
      result += isLast ? closing : "\n"
    }

    return result
  }

  // Wraps a long attribute value so space-delimited tokens align to the opening quote
  wrapAttribute(attr, startCol) {
    const eqIdx = attr.indexOf("=")
    if (eqIdx === -1) return attr

    const name = attr.slice(0, eqIdx)
    const rawValue = attr.slice(eqIdx + 1)
    const quote = rawValue[0]
    if (quote !== '"' && quote !== "'") return attr

    // Normalize: collapse internal whitespace/newlines into single spaces
    const inner = rawValue.slice(1, -1).replace(/\s+/g, " ").trim()

    // Check if it fits on one line
    const fullAttr = name + "=" + quote + inner + quote
    if (startCol + fullAttr.length <= this.maxLineLength) return fullAttr

    // Wrap space-delimited values, aligning to column after opening quote
    const prefix = name + "=" + quote
    const valueCol = startCol + prefix.length
    const valuePad = " ".repeat(valueCol)
    const words = inner.split(" ")

    const lines = []
    let currentLine = ""

    for (const word of words) {
      const testLine = currentLine ? currentLine + " " + word : word
      const lineCol = lines.length === 0 ? startCol + prefix.length : valueCol

      if (lineCol + testLine.length > this.maxLineLength && currentLine) {
        lines.push(currentLine)
        currentLine = word
      } else {
        currentLine = testLine
      }
    }
    if (currentLine) lines.push(currentLine)

    // First line gets the prefix, rest are padded, last gets closing quote
    let result = prefix + lines[0]
    for (let i = 1; i < lines.length; i++) {
      result += "\n" + valuePad + lines[i]
    }
    result += quote

    return result
  }

  // Returns the column offset of a position within its line
  columnOf(content, pos) {
    let col = 0
    let i = pos
    while (i > 0 && content[i - 1] !== "\n") {
      col++
      i--
    }
    return col
  }
}
