import { BaseRuleVisitor, getAttributes, getAttributeName } from "@herb-tools/linter"

/**
 * Flags inline `style` attributes on HTML elements.
 * Use Tailwind CSS utility classes instead of inline styles.
 *
 * Bad:  <div style="width: 50%">
 * Good: <div class="w-1/2">
 */
class NoInlineStylesVisitor extends BaseRuleVisitor {
  visitHTMLOpenTagNode(node) {
    const attributes = getAttributes(node)

    for (const attribute of attributes) {
      const attributeName = getAttributeName(attribute)

      if (attributeName === "style") {
        this.addOffense(
          `Avoid using inline \`style\` attributes. Use Tailwind CSS utility classes instead.`,
          attribute.location,
          "warning"
        )
      }
    }

    super.visitHTMLOpenTagNode(node)
  }
}

export default class NoInlineStylesRule {
  static ruleName = "no-inline-styles"

  check(parseResult, context) {
    const visitor = new NoInlineStylesVisitor(this.name, context)
    visitor.visit(parseResult.value)
    return visitor.offenses
  }
}
