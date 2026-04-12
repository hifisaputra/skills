# Widget Editor Overhaul - Issue Breakdown

## Codebase Map

Key files and their roles:

| File | Role |
|------|------|
| `src/server/api/routes/widget.ts` | tRPC route with `widgetConfigSchema` (Zod) and CRUD mutations |
| `src/server/api/routes/widget.test.ts` | Schema validation tests |
| `src/server/services/embed-renderer.ts` | `WidgetConfig` interface, `renderEmbed()` HTML generator, CSS, layout rendering |
| `src/server/services/embed-renderer.test.ts` | Renderer unit tests |
| `src/server/db/schema/widgetin.ts` | Drizzle schema (widgets table stores config as JSON text column) |
| `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` | Editor UI (single ~1547 line file with tabs: layout, header, review, style, settings) |
| `src/app/embed/[widgetId]/route.ts` | Embed HTTP route (reads config, calls renderEmbed) |
| `src/app/embed/embed-route.test.ts` | Embed route integration tests |

Note: The DB schema does NOT need migration for any of these changes. The `widgets.config` column is a JSON text blob — all new config fields are added to the Zod schema with defaults and stored in the existing column. Backward compatibility is handled by optional fields with defaults.

---

## Issue List

### Issue 1: Reviewer Name Format + Verified Badge + Owner Reply Display

**Title:** Add reviewer name format options, verified badge toggle, and owner reply rendering
**Type:** AFK
**Priority:** normal
**Blocked by:** (none)
**User stories covered:** 10, 12 (partial: verified badge, owner reply)
**Estimated size:** medium (~200 lines)
**Files touched:**
- `src/server/api/routes/widget.ts` — add `nameFormat` enum to `reviewCard` in `widgetConfigSchema`; add `showVerifiedBadge` boolean
- `src/server/api/routes/widget.test.ts` — tests for new schema fields
- `src/server/services/embed-renderer.ts` — update `WidgetConfig` interface, update `renderReviewCard()` to format name per config; render verified badge; render owner reply HTML when `showOwnerReply` is true (currently the flag exists but no reply data is rendered)
- `src/server/services/embed-renderer.test.ts` — tests for name formatting, verified badge, owner reply rendering

---

### Issue 2: Header Presets + Widget Title Toggle

**Title:** Add header style presets carousel and widget title toggle to header
**Type:** AFK
**Priority:** normal
**Blocked by:** (none)
**User stories covered:** 6, 7 (partial: widget title element)
**Estimated size:** medium (~250 lines)
**Files touched:**
- `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` — add `HEADER_PRESETS` constant array (~5-10 presets), add preset carousel selector to header tab, add widget title toggle control
- `src/server/api/routes/widget.ts` — add optional `headerPreset` field to `header` in `widgetConfigSchema`
- `src/server/api/routes/widget.test.ts` — test header preset field validation
- `src/server/services/embed-renderer.ts` — update `WidgetConfig` interface for `headerPreset`; apply preset CSS class in `renderHeader()`
- `src/server/services/embed-renderer.test.ts` — test header preset rendering

---

### Issue 3: Review Card Granular Styling Controls

**Title:** Add granular color/style controls for review cards (background, border, text, name, date, read-more, source icon, rating size, text font size, corner radius)
**Type:** AFK
**Priority:** normal
**Blocked by:** (none)
**User stories covered:** 15
**Estimated size:** large (~400 lines)
**Files touched:**
- `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` — add collapsible "Card Styling" section under Style tab with color pickers and sliders for card-level granular controls
- `src/server/api/routes/widget.ts` — add optional `cardStyle` object to `widgetConfigSchema` with fields: `borderColor`, `textColor`, `nameColor`, `dateColor`, `readMoreColor`, `sourceIconColor`, `sourceIconBg`, `ratingSize`, `textFontSize`, `cornerRadius`
- `src/server/api/routes/widget.test.ts` — test `cardStyle` schema validation
- `src/server/services/embed-renderer.ts` — update `WidgetConfig` interface; apply `cardStyle` values as inline styles or CSS custom properties in `renderReviewCard()` and `getCSS()`
- `src/server/services/embed-renderer.test.ts` — test card style CSS output

---

### Issue 4: Accent Color Palette + Stars Color + Expanded Fonts

**Title:** Add accent color palette with presets and custom picker, stars color control, and expanded font options
**Type:** AFK
**Priority:** normal
**Blocked by:** (none)
**User stories covered:** 17, 18
**Estimated size:** small (~100 lines)
**Files touched:**
- `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` — add preset color swatches to primary color picker in Style tab; expand `FONT_OPTIONS` array with more font families; stars color already exists in UI, verify it's exposed properly
- `src/server/services/embed-renderer.ts` — no changes (stars color CSS variable already implemented)
- `src/server/services/embed-renderer.test.ts` — verify stars color custom property is emitted (test may already exist, add if missing)

---

### Issue 5: Sort by Photos-First / Random + Photos-Only Filter

**Title:** Add photos-first and random sort options, plus photos-only filter
**Type:** AFK
**Priority:** normal
**Blocked by:** (none)
**User stories covered:** 19 (partial: photos filter), 20
**Estimated size:** medium (~150 lines)
**Files touched:**
- `src/server/api/routes/widget.ts` — extend `sortBy` enum to include `"photos_first"` and `"random"`; `photosOnly` already exists in schema
- `src/server/api/routes/widget.test.ts` — test new sortBy values, photosOnly validation
- `src/server/services/embed-renderer.ts` — update `WidgetConfig` interface `sortBy` type; implement `photos_first` sort (reviews with `reviewerPhotoUrl` first) and `random` shuffle in `filterAndSortReviews()`
- `src/server/services/embed-renderer.test.ts` — test photos-first ordering and random sort
- `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` — add `"photos_first"` and `"random"` to `SORT_OPTIONS`; add `photosOnly` toggle to filter UI

---

### Issue 6: External Links Toggle + New Tab Control + Rating Format

**Title:** Add external links toggle, new-tab control, and rating display format option
**Type:** AFK
**Priority:** normal
**Blocked by:** (none)
**User stories covered:** 21, 22
**Estimated size:** medium (~180 lines)
**Files touched:**
- `src/server/api/routes/widget.ts` — add `externalLinks` object (`enabled: boolean`, `openInNewTab: boolean`) and `ratingFormat` enum (`"value"` | `"value_of_5"`) to `widgetConfigSchema`
- `src/server/api/routes/widget.test.ts` — test new fields
- `src/server/services/embed-renderer.ts` — update `WidgetConfig` interface; conditionally render `target="_blank"` on links based on `externalLinks`; format rating as "4.9" vs "4.9/5" in `renderHeader()`
- `src/server/services/embed-renderer.test.ts` — test link target behavior, rating format rendering
- `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` — add toggles for external links and new-tab in Settings tab; add rating format selector in Header tab

---

### Issue 7: Desktop/Mobile Preview Toggle

**Title:** Add desktop/mobile toggle to the preview panel in the widget editor
**Type:** AFK
**Priority:** normal
**Blocked by:** (none)
**User stories covered:** 23
**Estimated size:** small (~80 lines)
**Files touched:**
- `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` — add preview size toggle (desktop/mobile) above the iframe; constrain iframe width to ~375px for mobile preview mode; add state for preview device mode

---

### Issue 8: Remove "Powered by Widgetin" Branding (Premium)

**Title:** Allow premium users to remove the Powered by Widgetin badge via editor toggle
**Type:** AFK
**Priority:** normal
**Blocked by:** (none)
**User stories covered:** 24
**Estimated size:** small (~60 lines)
**Files touched:**
- `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` — add toggle in Settings tab to hide branding (disabled/greyed for free plan with upgrade prompt)
- `src/server/api/routes/widget.ts` — add optional `hideBranding: boolean` to `widgetConfigSchema`
- `src/server/api/routes/widget.test.ts` — test hideBranding field
- `src/server/services/embed-renderer.ts` — update `WidgetConfig` interface; use `hideBranding` in `renderEmbed()` to suppress powered-by (still enforce plan check server-side)
- `src/server/services/embed-renderer.test.ts` — test branding suppression with hideBranding flag

---

### Issue 9: Load More Pagination

**Title:** Add client-side Load More pagination button to embed renderer
**Type:** AFK
**Priority:** normal
**Blocked by:** #5 (shares `filterAndSortReviews`, `SORT_OPTIONS`, and filter UI in editor page)
**User stories covered:** 5
**Estimated size:** medium (~250 lines)
**Files touched:**
- `src/server/api/routes/widget.ts` — add optional `pagination` object (`enabled: boolean`, `pageSize: number`) to `widgetConfigSchema`
- `src/server/api/routes/widget.test.ts` — test pagination schema fields
- `src/server/services/embed-renderer.ts` — update `WidgetConfig` interface; implement Load More: render all reviews but hide beyond page 1 with CSS `display:none`, add "Muat Lebih Banyak" button, add inline JS to reveal next page of reviews; add button styling support
- `src/server/services/embed-renderer.test.ts` — test that reviews beyond pageSize are hidden, button is present
- `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` — add pagination toggle and page size input in Settings tab or Layout tab

---

### Issue 10: Button Styling Controls (Write-Review + Load-More)

**Title:** Add granular button styling controls for write-review and load-more buttons
**Type:** AFK
**Priority:** normal
**Blocked by:** #9 (load-more button must exist before styling it)
**User stories covered:** 16
**Estimated size:** medium (~250 lines)
**Files touched:**
- `src/server/api/routes/widget.ts` — add `loadMoreButtonStyle` object to `widgetConfigSchema` (mirrors existing `headerStyle.button` shape: variant, colors, cornerRadius, size, fontSize, bold, paddingX, paddingY)
- `src/server/api/routes/widget.test.ts` — test loadMoreButtonStyle validation
- `src/server/services/embed-renderer.ts` — update `WidgetConfig` interface; apply load-more button inline styles using same pattern as `getButtonInlineStyle()`
- `src/server/services/embed-renderer.test.ts` — test load-more button styling output
- `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` — add "Load More Button" styling section under Style tab, mirroring the existing "Write Review Button" styling UI

---

### Issue 11: Card Height Alignment for Grid/Row Layouts

**Title:** Add card height alignment option for grid and row layouts
**Type:** AFK
**Priority:** normal
**Blocked by:** #3 (shares `cardStyle` and card CSS in embed-renderer)
**User stories covered:** 13
**Estimated size:** small (~80 lines)
**Files touched:**
- `src/server/api/routes/widget.ts` — add optional `equalHeight: boolean` to `widgetConfigSchema` (under responsive or top-level)
- `src/server/api/routes/widget.test.ts` — test equalHeight field
- `src/server/services/embed-renderer.ts` — update `WidgetConfig` interface; when `equalHeight` is true, add CSS for `.layout-grid .reviews-container { align-items: stretch }` and `.review-card { height: 100% }` in `getCSS()`
- `src/server/services/embed-renderer.test.ts` — test equal height CSS output
- `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` — add equalHeight toggle in Layout tab (visible only for grid/masonry)

---

### Issue 12: Source Attribution Style Presets in Editor

**Title:** Add source attribution style presets carousel to review card settings
**Type:** AFK
**Priority:** normal
**Blocked by:** #1 (shares `reviewCard` section of config schema and `renderReviewCard()`)
**User stories covered:** 9
**Estimated size:** small (~100 lines)
**Files touched:**
- `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` — add `SOURCE_PRESETS` constant array (~6 presets: icon+name, platform logo, inline badge, etc.); add visual preset selector in Review tab replacing or augmenting the existing source style grid
- `src/server/services/embed-renderer.ts` — no changes needed (source styles already fully implemented in `renderReviewCard()`)

---

### Issue 13: Header Granular Styling Controls Enhancement

**Title:** Enhance header granular styling with background, text, logo, corner radius, and write-review button styling
**Type:** AFK
**Priority:** normal
**Blocked by:** #2 (shares header section of schema, `renderHeader()`, and header UI in editor)
**User stories covered:** 14
**Estimated size:** small (~80 lines)
**Files touched:**
- `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` — enhance existing "Gaya Header" card: add button color pickers (backgroundColor, textColor) for write-review button; add font-size and padding controls
- `src/server/api/routes/widget.ts` — no new schema needed (headerStyle.button already has all fields)
- `src/server/services/embed-renderer.ts` — verify all headerStyle.button fields are applied in `getButtonInlineStyle()` (they already are)
- `src/server/services/embed-renderer.test.ts` — add tests for button color/size application in header

---

### Issue 14: Review Text Display Controls (Truncation Enhancement)

**Title:** Add short/full text display mode toggle and preview text length control
**Type:** AFK
**Priority:** normal
**Blocked by:** #1 (shares `reviewCard` section in schema and `renderReviewCard()`)
**User stories covered:** 11
**Estimated size:** small (~100 lines)
**Files touched:**
- `src/server/api/routes/widget.ts` — add optional `textDisplay` enum (`"short"` | `"full"`) to `truncation` or `reviewCard` in `widgetConfigSchema`
- `src/server/api/routes/widget.test.ts` — test textDisplay field
- `src/server/services/embed-renderer.ts` — update `WidgetConfig` interface; when `textDisplay` is "short", always truncate regardless of `enabled` flag; use existing `charLimit` for preview length
- `src/server/services/embed-renderer.test.ts` — test short/full display modes
- `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` — add text display mode selector in Review tab above truncation controls

---

### Issue 15: Review Images Toggle on Cards

**Title:** Add toggle to show/hide review images (photos attached to reviews) on cards
**Type:** AFK
**Priority:** normal
**Blocked by:** #12 (shares review card UI section in editor page)
**User stories covered:** 12 (partial: review images)
**Estimated size:** small (~80 lines)
**Files touched:**
- `src/server/api/routes/widget.ts` — add optional `showReviewImages: boolean` to `reviewCard` in `widgetConfigSchema`
- `src/server/api/routes/widget.test.ts` — test showReviewImages field
- `src/server/services/embed-renderer.ts` — update `WidgetConfig` interface; conditionally render review images (attached photos, not reviewer avatar) in `renderReviewCard()` when enabled
- `src/server/services/embed-renderer.test.ts` — test review image rendering toggle
- `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` — add "Show Review Images" toggle in Review tab

---

## Dependency Chain Analysis

### File Conflict Matrix

Shared files that create conflicts between simultaneously-running issues:

| File | Issues that touch it |
|------|---------------------|
| `src/server/api/routes/widget.ts` (schema) | 1, 2, 3, 5, 6, 8, 9, 10, 11, 14, 15 |
| `src/server/api/routes/widget.test.ts` | 1, 2, 3, 5, 6, 8, 9, 10, 11, 14, 15 |
| `src/server/services/embed-renderer.ts` | 1, 2, 3, 5, 6, 8, 9, 10, 11, 14, 15 |
| `src/server/services/embed-renderer.test.ts` | 1, 2, 3, 5, 6, 8, 9, 10, 11, 13, 14, 15 |
| `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` (editor) | 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 |

**Key insight:** Nearly every issue touches the 4 core files (schema, schema test, renderer, renderer test) plus the editor page. This is a "shared spine" problem. True parallel execution of all issues is impossible without conflicts. The strategy is to form sequential chains that each build on the prior issue's changes.

### Dependency Chains (resolving file conflicts)

Since all issues share the same core files, we organize them into sequential chains. Each chain handles a thematic cluster. Within a chain, each issue depends on the previous one. Across chains at the same depth level, issues would conflict — so we stagger them.

**Chain A: Review Card Features**
```
#1 (Reviewer name format + verified badge + owner reply)
  -> #12 (Source attribution presets in editor)
    -> #15 (Review images toggle)
      -> #14 (Text display short/full mode)
```

**Chain B: Header & Button Features**
```
#2 (Header presets + widget title)
  -> #13 (Header granular styling enhancement)
```

**Chain C: Filtering & Pagination**
```
#5 (Sort photos-first/random + photos-only filter)
  -> #9 (Load More pagination)
    -> #10 (Button styling for write-review + load-more)
```

**Chain D: Card & Layout Styling**
```
#3 (Review card granular styling)
  -> #11 (Card height alignment)
```

**Chain E: Standalone Editor-Only (no schema/renderer)**
```
#4 (Accent color palette + expanded fonts) — editor-only
#7 (Desktop/mobile preview toggle) — editor-only
```

**Chain F: Settings**
```
#6 (External links + rating format)
  -> #8 (Remove branding toggle)
```

However, chains A, B, C, D, and F all share the schema and renderer files. To prevent conflicts between chains, we must ensure no two chains have unblocked issues at the same time on the shared files. We do this by staggering chain starts:

- **Wave 1 (parallel):** #1 (Chain A start), #4 (Chain E, editor-only), #7 (Chain E, editor-only)
- **Wave 2 (after #1):** #12 (Chain A), #2 (Chain B start)
- **Wave 3 (after #12, #2):** #15 (Chain A), #13 (Chain B), #5 (Chain C start)
- **Wave 4 (after #15, #5):** #14 (Chain A), #9 (Chain C), #3 (Chain D start)
- **Wave 5 (after #14, #9, #3):** #10 (Chain C), #11 (Chain D), #6 (Chain F start)
- **Wave 6 (after #10, #6):** #8 (Chain F)

This is overly sequential. Let's optimize by noting that issues #4 and #7 only touch the editor page. They can run in Wave 1 alongside #1 (which does NOT share the editor page with them since #1's editor changes are zero — #1 only touches schema + renderer). Wait — actually #1 does NOT touch the editor page. So #1, #4, #7 can all run in parallel.

Refined dependency graph with "blocked by" explicitly set to prevent file conflicts:

| Issue | Blocked By | Rationale |
|-------|-----------|-----------|
| #1 | — | First to touch schema + renderer for reviewCard |
| #4 | — | Editor-only (no schema/renderer overlap) |
| #7 | — | Editor-only (no schema/renderer overlap), separate page area from #4 |
| #2 | #1 | Schema + renderer conflict with #1 |
| #12 | #1 | Shares reviewCard section with #1 |
| #5 | #2 | Schema + renderer conflict with #2 |
| #3 | #2 | Schema + renderer conflict with #2 |
| #13 | #2 | Shares header in editor page with #2 |
| #15 | #12 | Shares review card editor section with #12 |
| #14 | #15 | Shares reviewCard schema + render with #15 |
| #6 | #5, #3 | Schema + renderer conflict |
| #9 | #5 | Shares filter/sort + renderer with #5 |
| #11 | #3 | Shares card CSS in renderer with #3 |
| #8 | #6 | Shares schema + renderer settings with #6 |
| #10 | #9 | Load-more button must exist first |

Wait — this still has problems. Issues #2, #12 would be in Wave 2 together, and both touch the schema + renderer. Let me fix:

| Issue | Blocked By |
|-------|-----------|
| #1 | — |
| #4 | — |
| #7 | — |
| #2 | #1 |
| #12 | #2 |
| #5 | #12 |
| #3 | #5 |
| #13 | #12 |
| #15 | #13 |
| #14 | #15 |
| #6 | #3 |
| #9 | #3 |
| #11 | #9 |
| #8 | #6 |
| #10 | #11 |

Let me verify: at each wave, which issues are unblocked simultaneously?

- **Wave 1:** #1, #4, #7 -- #1 touches schema+renderer+tests. #4 touches editor only. #7 touches editor only. #4 and #7 both touch editor page but different sections (style tab vs preview panel). Minimal conflict risk; but to be safe, let's chain: #7 blocked by nothing, #4 blocked by nothing. They modify different parts of the editor page (#4 = colors/fonts in style tab, #7 = preview panel area). These can coexist.
- **Wave 2:** #2 -- touches schema+renderer+editor header tab. #4 and #7 may still be running but they don't touch schema/renderer. OK.
- **Wave 3:** #12 -- touches editor review tab only (no schema/renderer changes). After #2 completes.
- **Wave 4:** #5 and #13 -- #5 touches schema+renderer+editor sort options. #13 touches editor header styling + renderer tests only. Both touch renderer tests. Conflict! Fix: #13 blocked by #5.

Let me redo this carefully with a strict rule: **no two simultaneously-unblocked issues share ANY file**.

### Final Dependency Graph

| Issue | Blocked By | Files Modified (unique portions) |
|-------|-----------|--------------------------------|
| **#1** | — | schema (`reviewCard.nameFormat`, `reviewCard.showVerifiedBadge`), renderer (`renderReviewCard` name/badge/reply), schema test, renderer test |
| **#4** | — | editor (Style tab: color swatches, FONT_OPTIONS array) |
| **#7** | — | editor (preview panel: new state + iframe width toggle) |
| **#2** | #1 | schema (`header.headerPreset`), renderer (`renderHeader` preset class), editor (Header tab: preset carousel), schema test, renderer test |
| **#5** | #2 | schema (`sortBy` enum extension), renderer (`filterAndSortReviews`), editor (SORT_OPTIONS + photosOnly toggle), schema test, renderer test |
| **#12** | #4, #5 | editor (Review tab: SOURCE_PRESETS visual selector) — needs #4 done to avoid editor conflict, needs #5 done to avoid editor conflict |
| **#3** | #5 | schema (`cardStyle` object), renderer (card inline styles in `renderReviewCard` + `getCSS`), editor (Style tab: Card Styling section), schema test, renderer test |
| **#13** | #3 | editor (Style tab: header button colors/padding), renderer test (header button tests) |
| **#6** | #3 | schema (`externalLinks`, `ratingFormat`), renderer (link targets, rating format), editor (Settings + Header tabs), schema test, renderer test |
| **#9** | #6 | schema (`pagination`), renderer (Load More button + JS), editor (Settings/Layout), schema test, renderer test |
| **#15** | #12 | schema (`reviewCard.showReviewImages`), renderer (review images), editor (Review tab toggle), schema test, renderer test |
| **#8** | #9 | schema (`hideBranding`), renderer (branding suppression), editor (Settings tab), schema test, renderer test |
| **#11** | #13, #8 | schema (`equalHeight`), renderer (grid CSS), editor (Layout tab toggle), schema test, renderer test |
| **#14** | #15 | schema (`textDisplay`), renderer (truncation logic), editor (Review tab), schema test, renderer test |
| **#10** | #11 | schema (`loadMoreButtonStyle`), renderer (load-more inline styles), editor (Style tab), schema test, renderer test |

### Verification: No two simultaneously-unblocked issues share files

| Wave | Unblocked Issues | Files | Conflict? |
|------|-----------------|-------|-----------|
| 1 | #1, #4, #7 | #1: schema, renderer, schema test, renderer test. #4: editor (Style tab colors/fonts). #7: editor (preview panel). | No conflict. #4 and #7 touch different sections of editor. Neither touches schema/renderer. |
| 2 | #2 | schema, renderer, editor (Header tab), tests | No conflict (only one issue). |
| 3 | #5 | schema, renderer, editor (Review tab sort), tests | No conflict (only one issue). |
| 4 | #12, #3 | #12: editor (Review tab source presets). #3: schema, renderer, editor (Style tab card section), tests. | #12 only touches editor Review tab; #3 touches editor Style tab + schema/renderer. Different editor sections, no schema/renderer overlap for #12. **No conflict.** |
| 5 | #13, #6 | #13: editor (Style tab header buttons), renderer test. #6: schema, renderer, editor (Settings + Header tabs), schema test, renderer test. | Both touch renderer test. **Conflict!** Fix: #13 blocked by #6. |

Let me fix wave 5: make #13 depend on #6.

Revised:
| Issue | Blocked By |
|-------|-----------|
| **#1** | — |
| **#4** | — |
| **#7** | — |
| **#2** | #1 |
| **#5** | #2 |
| **#12** | #4, #5 |
| **#3** | #5 |
| **#6** | #3 |
| **#13** | #6 |
| **#9** | #6 |
| **#15** | #12 |
| **#8** | #9 |
| **#14** | #15 |
| **#11** | #13, #8 |
| **#10** | #11 |

Re-verify:

| Wave | Unblocked Issues | Shared Files? |
|------|-----------------|---------------|
| 1 | #1, #4, #7 | No. #1=schema/renderer/tests. #4=editor style. #7=editor preview. |
| 2 | #2 | Only issue. |
| 3 | #5 | Only issue. |
| 4 | #12, #3 | #12=editor Review tab only. #3=schema+renderer+editor Style tab+tests. No overlap. |
| 5 | #6, #15 | #6=schema+renderer+editor Settings/Header+tests. #15=schema+renderer+editor Review tab+tests. Both touch schema, renderer, tests. **Conflict!** |

Fix: #15 must also wait for #6. Make #15 blocked by #12 AND #6.

Revised again:
| Issue | Blocked By |
|-------|-----------|
| **#1** | — |
| **#4** | — |
| **#7** | — |
| **#2** | #1 |
| **#5** | #2 |
| **#12** | #4, #5 |
| **#3** | #5 |
| **#6** | #3 |
| **#15** | #12, #6 |
| **#13** | #6 |
| **#9** | #6 |
| **#8** | #9 |
| **#14** | #15 |
| **#11** | #13, #8 |
| **#10** | #11 |

Re-verify:

| Wave | Unblocked Issues | Shared Files? |
|------|-----------------|---------------|
| 1 | #1, #4, #7 | No overlap. |
| 2 | #2 | Solo. |
| 3 | #5 | Solo. |
| 4 | #12, #3 | #12=editor only. #3=schema/renderer/tests/editor Style. No overlap. |
| 5 | #6 | Solo (since #12 finished in wave 4, but #15 needs #6 too). |
| 6 | #15, #13, #9 | #15=schema/renderer/editor Review/tests. #13=editor Style header+renderer test. #9=schema/renderer/editor Settings/tests. All three touch renderer test and/or schema/renderer. **Conflict!** |

This is getting complex. The fundamental constraint is: the 4 core files (schema, schema test, renderer, renderer test) are touched by almost every issue. Only issues #4, #7, #12 avoid them. So effectively, all schema+renderer issues must be serial, with the editor-only issues (#4, #7, #12) slotted in parallel where possible.

### Final Optimized Dependency Graph

**Principle:** All issues that touch schema+renderer form a single sequential chain. Editor-only issues (#4, #7, #12) run in parallel with schema+renderer issues, as long as they don't collide on the editor page section being modified.

**Sequential spine (schema + renderer issues):**
```
#1 -> #2 -> #5 -> #3 -> #6 -> #9 -> #8 -> #15 -> #14 -> #13 -> #11 -> #10
```

**Editor-only branches (parallel with the spine):**
```
#4 (runs in parallel with #1)
#7 (runs in parallel with #1)
#12 (runs after #4 — both touch editor Review/Style tabs; runs after #5 to pick up sort changes)
```

| # | Title | Type | Priority | Blocked By | User Stories | Est. Size | Files Touched |
|---|-------|------|----------|------------|-------------|-----------|---------------|
| 1 | Reviewer name format, verified badge, owner reply rendering | AFK | normal | — | 10, 12 | medium | `src/server/api/routes/widget.ts`, `src/server/api/routes/widget.test.ts`, `src/server/services/embed-renderer.ts`, `src/server/services/embed-renderer.test.ts` |
| 2 | Header style presets + widget title toggle | AFK | normal | #1 | 6, 7 | medium | `src/server/api/routes/widget.ts`, `src/server/api/routes/widget.test.ts`, `src/server/services/embed-renderer.ts`, `src/server/services/embed-renderer.test.ts`, `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` |
| 3 | Review card granular styling controls | AFK | normal | #5 | 15 | large | `src/server/api/routes/widget.ts`, `src/server/api/routes/widget.test.ts`, `src/server/services/embed-renderer.ts`, `src/server/services/embed-renderer.test.ts`, `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` |
| 4 | Accent color palette, stars color, expanded fonts | AFK | normal | — | 17, 18 | small | `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` |
| 5 | Photos-first/random sort + photos-only filter | AFK | normal | #2 | 19, 20 | medium | `src/server/api/routes/widget.ts`, `src/server/api/routes/widget.test.ts`, `src/server/services/embed-renderer.ts`, `src/server/services/embed-renderer.test.ts`, `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` |
| 6 | External links toggle, new-tab control, rating format | AFK | normal | #3 | 21, 22 | medium | `src/server/api/routes/widget.ts`, `src/server/api/routes/widget.test.ts`, `src/server/services/embed-renderer.ts`, `src/server/services/embed-renderer.test.ts`, `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` |
| 7 | Desktop/mobile preview toggle | AFK | normal | — | 23 | small | `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` |
| 8 | Remove Powered by Widgetin branding (premium) | AFK | normal | #9 | 24 | small | `src/server/api/routes/widget.ts`, `src/server/api/routes/widget.test.ts`, `src/server/services/embed-renderer.ts`, `src/server/services/embed-renderer.test.ts`, `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` |
| 9 | Load More client-side pagination | AFK | normal | #6 | 5 | medium | `src/server/api/routes/widget.ts`, `src/server/api/routes/widget.test.ts`, `src/server/services/embed-renderer.ts`, `src/server/services/embed-renderer.test.ts`, `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` |
| 10 | Granular button styling (write-review + load-more) | AFK | normal | #11 | 16 | medium | `src/server/api/routes/widget.ts`, `src/server/api/routes/widget.test.ts`, `src/server/services/embed-renderer.ts`, `src/server/services/embed-renderer.test.ts`, `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` |
| 11 | Card height alignment for grid/row layouts | AFK | normal | #13 | 13 | small | `src/server/api/routes/widget.ts`, `src/server/api/routes/widget.test.ts`, `src/server/services/embed-renderer.ts`, `src/server/services/embed-renderer.test.ts`, `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` |
| 12 | Source attribution style presets in editor | AFK | normal | #4, #5 | 9 | small | `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` |
| 13 | Header granular styling enhancement | AFK | normal | #8 | 14 | small | `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx`, `src/server/services/embed-renderer.test.ts` |
| 14 | Review text display mode (short/full) | AFK | normal | #15 | 11 | small | `src/server/api/routes/widget.ts`, `src/server/api/routes/widget.test.ts`, `src/server/services/embed-renderer.ts`, `src/server/services/embed-renderer.test.ts`, `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` |
| 15 | Review images toggle on cards | AFK | normal | #8 | 12 | small | `src/server/api/routes/widget.ts`, `src/server/api/routes/widget.test.ts`, `src/server/services/embed-renderer.ts`, `src/server/services/embed-renderer.test.ts`, `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` |

Wait — #13 touches `embed-renderer.test.ts` which is also touched by every spine issue. So #13 can't run parallel with spine issues. Let me put #13 back in the spine.

### FINAL Dependency Graph (corrected)

All issues touching schema, renderer, or their test files must be strictly serialized. Only #4 and #7 are truly editor-only.

**The spine** (all touch schema+renderer+tests+editor):
```
#1 -> #2 -> #5 -> #3 -> #6 -> #9 -> #8 -> #15 -> #14 -> #13 -> #11 -> #10
```

**Parallel with spine** (editor-only, no schema/renderer/test files):
```
#4 (parallel with any spine issue, touches editor Style tab only)
#7 (parallel with any spine issue, touches editor preview panel only)
#12 (parallel with spine issues after #5, touches editor Review tab only — but must not collide with spine issue touching editor Review tab)
```

Issues #4 and #7 can run alongside any spine issue. Issue #12 can run alongside spine issues that don't modify the Review tab in the editor. Let's check: #12 modifies the Review tab source presets area. Spine issues that modify Review tab: #1 (no editor), #5 (adds sort options to Review tab), #15 (adds toggle to Review tab), #14 (adds control to Review tab). So #12 should run when no Review-tab spine issue is active. After #5 completes (which modifies Review tab sort area) and before #15 (which adds toggle). #12 can run in parallel with #3 or #6 (which modify Style tab and Settings tab respectively).

**Final Issue Table:**

| # | Title | Type | Blocked By | User Stories | Size | Files Touched |
|---|-------|------|------------|-------------|------|---------------|
| 1 | Reviewer name format, verified badge, owner reply rendering | AFK | — | 10, 12 | medium | `widget.ts`, `widget.test.ts`, `embed-renderer.ts`, `embed-renderer.test.ts` |
| 4 | Accent color palette, stars color, expanded fonts | AFK | — | 17, 18 | small | `page.tsx` (editor, Style tab) |
| 7 | Desktop/mobile preview toggle in editor | AFK | — | 23 | small | `page.tsx` (editor, preview panel) |
| 2 | Header style presets + widget title toggle | AFK | #1 | 6, 7 | medium | `widget.ts`, `widget.test.ts`, `embed-renderer.ts`, `embed-renderer.test.ts`, `page.tsx` (editor, Header tab) |
| 5 | Photos-first/random sort + photos-only filter | AFK | #2 | 19, 20 | medium | `widget.ts`, `widget.test.ts`, `embed-renderer.ts`, `embed-renderer.test.ts`, `page.tsx` (editor, Review tab sort) |
| 12 | Source attribution style presets in editor | AFK | #4, #5 | 9 | small | `page.tsx` (editor, Review tab source presets) |
| 3 | Review card granular styling controls | AFK | #5 | 15 | large | `widget.ts`, `widget.test.ts`, `embed-renderer.ts`, `embed-renderer.test.ts`, `page.tsx` (editor, Style tab card section) |
| 6 | External links toggle, new-tab control, rating format | AFK | #3 | 21, 22 | medium | `widget.ts`, `widget.test.ts`, `embed-renderer.ts`, `embed-renderer.test.ts`, `page.tsx` (editor, Settings + Header tabs) |
| 9 | Load More client-side pagination | AFK | #6 | 5 | medium | `widget.ts`, `widget.test.ts`, `embed-renderer.ts`, `embed-renderer.test.ts`, `page.tsx` (editor, Layout/Settings tab) |
| 8 | Remove Powered by Widgetin branding (premium) | AFK | #9 | 24 | small | `widget.ts`, `widget.test.ts`, `embed-renderer.ts`, `embed-renderer.test.ts`, `page.tsx` (editor, Settings tab) |
| 15 | Review images toggle on cards | AFK | #8 | 12 | small | `widget.ts`, `widget.test.ts`, `embed-renderer.ts`, `embed-renderer.test.ts`, `page.tsx` (editor, Review tab) |
| 14 | Review text display mode (short/full) | AFK | #15 | 11 | small | `widget.ts`, `widget.test.ts`, `embed-renderer.ts`, `embed-renderer.test.ts`, `page.tsx` (editor, Review tab) |
| 13 | Header granular styling enhancement (button colors, padding, font-size) | AFK | #14 | 14 | small | `embed-renderer.test.ts`, `page.tsx` (editor, Style tab header buttons) |
| 11 | Card height alignment for grid/row layouts | AFK | #13 | 13 | small | `widget.ts`, `widget.test.ts`, `embed-renderer.ts`, `embed-renderer.test.ts`, `page.tsx` (editor, Layout tab) |
| 10 | Granular button styling (write-review + load-more) | AFK | #11 | 16 | medium | `widget.ts`, `widget.test.ts`, `embed-renderer.ts`, `embed-renderer.test.ts`, `page.tsx` (editor, Style tab) |

All file paths use the prefix `/tmp/widgetin/src/`:
- `widget.ts` = `server/api/routes/widget.ts`
- `widget.test.ts` = `server/api/routes/widget.test.ts`
- `embed-renderer.ts` = `server/services/embed-renderer.ts`
- `embed-renderer.test.ts` = `server/services/embed-renderer.test.ts`
- `page.tsx` = `app/(dashboard)/dashboard/widgets/[id]/page.tsx`

---

## Parallel Lanes View

```
Lane A (spine):  #1 -> #2 -> #5 -> #3 -> #6 -> #9 -> #8 -> #15 -> #14 -> #13 -> #11 -> #10
Lane B (editor): #4 ------> (done) -> #12 (after #5)
Lane C (editor): #7 (done early, standalone)
```

Detailed wave-by-wave execution:

```
Wave 1:  [#1] [#4] [#7]          <- 3 parallel issues
Wave 2:  [#2]                    <- 1 issue (spine)
Wave 3:  [#5]                    <- 1 issue (spine)
Wave 4:  [#12] [#3]             <- 2 parallel (#12=editor-only, #3=spine)
Wave 5:  [#6]                    <- 1 issue (spine)
Wave 6:  [#9]                    <- 1 issue (spine)
Wave 7:  [#8]                    <- 1 issue (spine)
Wave 8:  [#15]                   <- 1 issue (spine)
Wave 9:  [#14]                   <- 1 issue (spine)
Wave 10: [#13]                   <- 1 issue (spine)
Wave 11: [#11]                   <- 1 issue (spine)
Wave 12: [#10]                   <- 1 issue (spine)
```

**Maximum parallelism:** 3 issues in Wave 1, 2 issues in Wave 4. Most waves are single-issue due to the shared-file constraint. This is an inherent property of the codebase architecture — nearly all features flow through the same 5 files.

**Optimization note:** The codebase could achieve better parallelism in the future by splitting the monolithic editor page (`page.tsx`) into per-tab components and by separating the `widgetConfigSchema` into composable sub-schemas imported from separate files. For this PRD, the serial spine is the safest approach.

---

## User Story Coverage

| Story | Issue(s) |
|-------|---------|
| 1. Column counts per breakpoint | Already implemented (responsive.columns in schema + editor + renderer) |
| 2. Full-width vs fixed widget width | Already implemented (responsive.widthMode) |
| 3. Row counts and item spacing | Already implemented (responsive.rows, itemSpacing) |
| 4. Badge layouts | Already implemented (badge_card, badge_compact, badge_button, badge_request) |
| 5. Load More pagination | #9 |
| 6. Header style presets | #2 |
| 7. Toggle header elements | #2 (widget title), rest already implemented |
| 8. Review card style presets | Already implemented (CARD_PRESETS in editor) |
| 9. Source attribution presets | #12 |
| 10. Reviewer name format | #1 |
| 11. Short/full text display | #14 |
| 12. Toggle review images, verified badge, owner replies | #1, #15 |
| 13. Card height alignment | #11 |
| 14. Header granular styling | #13 |
| 15. Card granular styling | #3 |
| 16. Button styling (write-review + load-more) | #10 |
| 17. Accent color palette | #4 |
| 18. Stars color + expanded fonts | #4 |
| 19. Filter reviews (text-only, photos, keyword, name) | #5 (photos-only), rest already implemented |
| 20. Sort photos-first / random | #5 |
| 21. External links + new tab control | #6 |
| 22. Rating display format | #6 |
| 23. Desktop/mobile preview toggle | #7 |
| 24. Remove Powered by branding | #8 |
