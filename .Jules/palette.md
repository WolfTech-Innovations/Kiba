## 2026-05-27 - [Semantic Structure and Focus Indicators]

**Learning:** CSS `transition` for `outline-color` requires a base `outline: 2px solid transparent` on the element; otherwise, the transition may jump or fail to animate smoothly when switching to the focus state. Additionally, applying `aria-label` to container elements (like feature cards) that already contain clear `<h2>` and `<p>` tags causes redundant announcements for screen reader users.

**Action:** Always define a transparent base outline when planning focus-state transitions. Use semantic `role="list"` and `role="listitem"` for card collections, but rely on internal headings for labeling unless the card content is non-textual or ambiguous.
