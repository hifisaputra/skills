# Widget Editor Overhaul - Issue Breakdown

## Codebase Exploration Summary

**Stack:** Next.js (App Router) + tRPC v11 + Drizzle ORM (SQLite/D1) + Tailwind CSS + shadcn/ui

### Key files mapped:

| Module | Files |
|--------|-------|
| **Config schema (Zod)** | `src/server/api/routes/widget.ts` (lines 14-175: `widgetConfigSchema`) |
| **WidgetConfig TS interface** | `src/server/services/embed-renderer.ts` (lines 1-96: `WidgetConfig` interface) |
| **Embed renderer** | `src/server/services/embed-renderer.ts` (~880 lines total: CSS generation, HTML rendering, filtering/sorting, layout templates) |
| **Embed route** | `src/app/embed/[widgetId]/route.ts` (serves HTML, preview mode, plan gating) |
| **Widget editor page** | `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` (~1547 lines: all editor tabs, preview iframe) |
| **DB schema** | `src/server/db/schema/widgetin.ts` (widgets table has `config` JSON column) |
| **Widget tRPC router** | `src/server/api/routes/widget.ts` (CRUD + `updateConfig` mutation) |
| **tRPC root** | `src/server/api/root.ts` (barrel file for all routers) |
| **Embed renderer tests** | `src/server/services/embed-renderer.test.ts` |
| **Widget schema tests** | `src/server/api/routes/widget.test.ts` |
| **Embed route tests** | `src/app/embed/embed-route.test.ts` |
| **DB default config** | `src/server/db/schema/widgetin.ts` (lines 73-115: default JSON in widgets table) |
| **Billing/plan logic** | `src/server/services/view-tracking.ts`, `src/server/services/billing.ts` |

### Architecture notes:
- Config is stored as a JSON blob in the `widgets.config` column (no migration needed for new fields).
- The Zod schema in `widget.ts` and the TS interface in `embed-renderer.ts` must stay in sync manually.
- All new config fields need defaults for backward compatibility.
- The editor page is a single monolithic component (~1547 lines) that already has 5 tabs: Layout, Header, Review, Style, Settings.
- The embed renderer generates standalone HTML with inline CSS/JS -- no external assets.

### File ownership boundaries:
- **Schema layer**: `widget.ts` (Zod schema) + `embed-renderer.ts` (TS interface) -- these MUST change together
- **Renderer layer**: `embed-renderer.ts` (CSS generation + HTML rendering)
- **Editor UI layer**: `dashboard/widgets/[id]/page.tsx` (React editor component)
- **Embed delivery**: `embed/[widgetId]/route.ts` (serves embed, plan checks)
- **Tests**: co-located `.test.ts` files

---

## Issue Breakdown

### Issue 1: Extend config schema with new card styling and reviewer name format fields

- **Title**: Add granular card styling and reviewer name format to config schema
- **Type**: AFK
- **Priority**: critical
- **Blocked by**: (none)
- **User stories covered**: 10, 13, 15
- **Estimated size**: medium (~150-200 lines)
- **Files touched**:
  - `src/server/api/routes/widget.ts` -- add new fields to `widgetConfigSchema`: `reviewCard.nameFormat`, `reviewCard.equalHeight`, `cardStyle` object (background, border color, text color, read-more color, name color, date color, source icon color, source icon bg, rating size, text font size, corner radius)
  - `src/server/services/embed-renderer.ts` -- update `WidgetConfig` interface to match new schema fields
  - `src/server/db/schema/widgetin.ts` -- update default config JSON in widgets table definition (add defaults for new fields)
  - `src/server/api/routes/widget.test.ts` -- add tests for new schema fields
  - `src/server/services/embed-renderer.test.ts` -- update `defaultConfig` in tests

### Issue 2: Extend config schema with sorting, pagination, links, rating format, and branding fields

- **Title**: Add sort options, Load More config, external link controls, rating format, and branding removal to config schema
- **Type**: AFK
- **Priority**: critical
- **Blocked by**: (none)
- **User stories covered**: 5, 20, 21, 22, 24
- **Estimated size**: medium (~150-200 lines)
- **Files touched**:
  - `src/server/api/routes/widget.ts` -- extend `widgetConfigSchema.filters.sortBy` enum with `"photos_first"`, `"random"`; add `pagination` object (enabled, pageSize); add `links` object (externalLinks boolean, newTab boolean); add `ratingFormat` enum (`"value"`, `"value_of_5"`); add `branding.hidePoweredBy` boolean
  - `src/server/services/embed-renderer.ts` -- update `WidgetConfig` interface for new fields
  - `src/server/db/schema/widgetin.ts` -- update default config JSON
  - `src/server/api/routes/widget.test.ts` -- add validation tests for new sort values, pagination, links, branding

### Issue 3: Implement granular card styling in embed renderer

- **Title**: Render granular card styles and reviewer name format in embed HTML/CSS
- **Type**: AFK
- **Priority**: high
- **Blocked by**: #1
- **User stories covered**: 10, 13, 15
- **Estimated size**: medium (~200-300 lines)
- **Files touched**:
  - `src/server/services/embed-renderer.ts` -- add CSS custom properties for new card style fields, implement `nameFormat` rendering (full name / first+last initial / initial+last name), implement `equalHeight` CSS for grid/row layouts, add inline styles from `cardStyle` config to review cards
  - `src/server/services/embed-renderer.test.ts` -- add tests for name format rendering, card style CSS properties, equal height behavior

### Issue 4: Implement Load More pagination, new sort options, and link controls in embed renderer

- **Title**: Add Load More button, photos-first/random sort, and external link controls to embed
- **Type**: AFK
- **Priority**: high
- **Blocked by**: #2
- **User stories covered**: 5, 20, 21, 22, 24
- **Estimated size**: large (~300-400 lines)
- **Files touched**:
  - `src/server/services/embed-renderer.ts` -- implement `photos_first` sort (reviews with `reviewerPhotoUrl` first), `random` sort (seeded shuffle), client-side Load More pagination (hide reviews beyond pageSize, JS button to reveal), rating format rendering ("4.9" vs "4.9/5"), `target="_blank"` gating on external links, conditional powered-by removal for `branding.hidePoweredBy` + pro plan
  - `src/server/services/embed-renderer.test.ts` -- test Load More HTML structure, new sort orders, link target behavior, rating format output, branding removal

### Issue 5: Add header style presets and header preset selector to editor UI

- **Title**: Implement header style presets with carousel selector in editor
- **Type**: AFK
- **Priority**: normal
- **Blocked by**: #1
- **User stories covered**: 6, 7, 14
- **Estimated size**: medium (~200-250 lines)
- **Files touched**:
  - `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` -- add `HEADER_PRESETS` constant array (~5-10 preset objects), add preset carousel selector UI to Header tab, wire presets to set `headerStyle` config values

### Issue 6: Add card style editor controls and reviewer name format selector to editor UI

- **Title**: Add granular card styling controls and name format picker to editor
- **Type**: AFK
- **Priority**: normal
- **Blocked by**: #1, #3
- **User stories covered**: 10, 13, 15
- **Estimated size**: medium (~250-300 lines)
- **Files touched**:
  - `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` -- add collapsible "Card Styling" section under Style tab with color pickers for each card element (background, border, text, read-more link, name, date, source icon, source icon bg), rating size slider, text font size slider, card corner radius slider; add name format dropdown to Review tab; add equal height toggle to Layout tab (grid/masonry only); add `updateCardStyle` callback helper

### Issue 7: Add filter/sort/pagination/link controls and branding toggle to editor UI

- **Title**: Add photos-first/random sort, Load More, link controls, rating format, and branding toggle to editor
- **Type**: AFK
- **Priority**: normal
- **Blocked by**: #2, #4
- **User stories covered**: 5, 20, 21, 22, 24
- **Estimated size**: medium (~200-250 lines)
- **Files touched**:
  - `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` -- extend `SORT_OPTIONS` array with "photos_first" and "random"; add Load More toggle + page size slider to Settings tab; add external links toggle + new tab toggle to Settings tab; add rating format selector to Header tab; add "Hide Powered By" toggle to Settings tab (gated to pro plan); update config merge in `useEffect` for new nested objects (`pagination`, `links`, `branding`)

### Issue 8: Add accent color palette with presets and custom picker to editor UI

- **Title**: Implement accent color palette with preset swatches and custom color picker
- **Type**: AFK
- **Priority**: normal
- **Blocked by**: (none)
- **User stories covered**: 17, 18
- **Estimated size**: small (~80-100 lines)
- **Files touched**:
  - `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` -- add `ACCENT_COLORS` constant array (~8-10 preset hex values), add accent color palette UI in Style tab (clickable color swatches + custom picker that sets `colors.primary`), extend `FONT_OPTIONS` with additional font choices (e.g., Raleway, Playfair Display, Work Sans, DM Sans)

### Issue 9: Add desktop/mobile preview toggle to editor

- **Title**: Add responsive desktop/mobile toggle to preview panel
- **Type**: AFK
- **Priority**: normal
- **Blocked by**: (none)
- **User stories covered**: 23
- **Estimated size**: small (~50-80 lines)
- **Files touched**:
  - `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` -- add `previewMode` state (`"desktop"` / `"mobile"`), add toggle buttons above the preview iframe, constrain iframe width to ~375px when mobile mode is active, style the preview container accordingly

### Issue 10: Implement photosOnly filter in schema, renderer, and editor

- **Title**: Add photos-only filter toggle end-to-end
- **Type**: AFK
- **Priority**: normal
- **Blocked by**: #2
- **User stories covered**: 19
- **Estimated size**: small (~60-80 lines)
- **Files touched**:
  - `src/server/services/embed-renderer.ts` -- add `photosOnly` filter logic in `filterAndSortReviews` (filter reviews where `reviewerPhotoUrl` is non-null; note: current schema stores reviewer photos, not review images -- this filter applies to reviewer photo presence)
  - `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` -- add "Photos only" toggle in Filter section
  - `src/server/services/embed-renderer.test.ts` -- test photosOnly filtering

### Issue 11: Add button styling controls (Load More + Write Review) to editor and renderer

- **Title**: Implement granular button styling for Load More and Write Review buttons
- **Type**: AFK
- **Priority**: normal
- **Blocked by**: #4, #5
- **User stories covered**: 16
- **Estimated size**: medium (~150-200 lines)
- **Files touched**:
  - `src/server/api/routes/widget.ts` -- add `loadMoreButtonStyle` object to schema (mirrors existing `headerStyle.button` shape: variant, colors, cornerRadius, size, fontSize, bold, padding)
  - `src/server/services/embed-renderer.ts` -- update WidgetConfig interface, apply `loadMoreButtonStyle` inline styles to the Load More button HTML, update CSS
  - `src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` -- add "Load More Button" styling section under Style tab, add `updateLoadMoreButton` callback

---

## File-Overlap Analysis

### File footprint matrix

| Issue | `widget.ts` (schema) | `embed-renderer.ts` (interface+render) | `widgetin.ts` (DB defaults) | `page.tsx` (editor) | `widget.test.ts` | `embed-renderer.test.ts` | `embed-route.test.ts` |
|-------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| #1 Schema: card style + name format | X | X (interface only) | X | | X | X | |
| #2 Schema: sort/pagination/links/brand | X | X (interface only) | X | | X | | |
| #3 Renderer: card styles | | X | | | | X | |
| #4 Renderer: Load More/sort/links/brand | | X | | | | X | |
| #5 Editor: header presets | | | | X | | | |
| #6 Editor: card style controls | | | | X | | | |
| #7 Editor: filter/sort/pagination/links | | | | X | | | |
| #8 Editor: accent palette + fonts | | | | X | | | |
| #9 Editor: preview toggle | | | | X | | | |
| #10 Filter: photosOnly | | X | | X | | X | |
| #11 Button styling | X | X | | X | | | |

### Conflict identification

**Hot file: `widget.ts` (schema)** -- touched by #1, #2, #11
**Hot file: `embed-renderer.ts`** -- touched by #1 (interface), #2 (interface), #3 (render), #4 (render), #10, #11
**Hot file: `page.tsx` (editor)** -- touched by #5, #6, #7, #8, #9, #10, #11
**Hot file: `widgetin.ts` (DB defaults)** -- touched by #1, #2
**Hot file: `embed-renderer.test.ts`** -- touched by #1, #3, #4, #10

### Conflict resolution via dependencies

1. **#1 and #2 both touch `widget.ts`, `embed-renderer.ts` (interface), `widgetin.ts`**: These are both schema-extension issues. They modify different sections of the schema (card style fields vs. sort/pagination/links fields) so they COULD potentially run in parallel if changes are additive. However, since both modify the same 3 files, **serialize them**: #1 goes first (establishes pattern), #2 follows.

2. **#3 and #4 both touch `embed-renderer.ts` and `embed-renderer.test.ts`**: They modify different rendering functions (card styling vs. pagination/sort) but in the same file. **Serialize**: #3 depends on #1, #4 depends on #2. Since #1 must come before #2, the chain is #1 -> #3, #2 -> #4, and #3 before #4 to avoid renderer file conflicts.

3. **#5, #6, #7, #8, #9, #10, #11 all touch `page.tsx`**: This is the biggest conflict. They modify different tabs/sections, but it's one file. Strategy:
   - **#5** (header presets) -- depends on #1 (schema), modifies Header tab
   - **#6** (card style controls) -- depends on #1 + #3, modifies Style + Review tabs
   - **#7** (filter/sort/links) -- depends on #2 + #4, modifies Settings + Review tabs
   - **#8** (accent palette) -- no schema dependency, modifies Style tab
   - **#9** (preview toggle) -- no schema dependency, modifies preview panel
   - **#10** (photosOnly) -- depends on #2, modifies Review tab + renderer
   - **#11** (button styling) -- depends on #4 + #5, modifies Style tab + schema + renderer

   To avoid page.tsx conflicts, serialize editor issues into chains:
   - **Editor chain A**: #5 -> #6 -> #11 (header presets -> card controls -> button styling)
   - **Editor chain B**: #8 -> #9 (accent palette -> preview toggle -- smallest, independent)
   - **Editor chain C**: #7 -> #10 (filter/sort controls -> photosOnly)

   Within each chain, issues are serialized. Between chains, they conflict on `page.tsx`. So chains must also be serialized, OR we accept that one chain starts only after the prior chain's first issue lands.

   **Final decision**: Since `page.tsx` is unavoidable across all editor issues, we place #8 and #9 early (no schema dependencies) as the first editor issues, then gate later editor issues behind them.

### Dependency graph

```
#1 (Schema: card style)
  |-> #3 (Renderer: card styles)
  |     |-> #6 (Editor: card style controls)
  |-> #5 (Editor: header presets)
  |     |-> #11 (Editor+Renderer: button styling)

#2 (Schema: sort/pagination/links)  [blocked by #1]
  |-> #4 (Renderer: Load More/sort/links)
  |     |-> #7 (Editor: filter/sort/pagination)
  |           |-> #10 (Editor+Renderer: photosOnly)

#8 (Editor: accent palette)  [no deps, but serialized after #6 for page.tsx safety]
#9 (Editor: preview toggle)  [no deps, but serialized after #8 for page.tsx safety]
```

### Parallel lanes view

```
Lane 1 (Schema + Renderer chain):
  #1 Schema: card style + name format
    -> #2 Schema: sort/pagination/links/brand
      -> #3 Renderer: card styles
        -> #4 Renderer: Load More/sort/links/brand

Lane 2 (Editor chain A - runs after Lane 1 issues it depends on):
  #5 Editor: header presets  [after #1]
    -> #6 Editor: card style controls  [after #3]
      -> #11 Editor+Renderer: button styling  [after #4, #5]

Lane 3 (Editor chain B - runs after #6 for page.tsx safety):
  #8 Editor: accent palette  [after #6]
    -> #9 Editor: preview toggle  [after #8]

Lane 4 (Editor chain C - runs after #11 for page.tsx safety):
  #7 Editor: filter/sort/pagination/links  [after #4, #11]
    -> #10 Editor+Renderer: photosOnly  [after #7]
```

### Execution timeline (maximizing parallelism while avoiding file conflicts)

```
Phase 1:  #1 (schema: card)          [Lane 1]
Phase 2:  #2 (schema: sort/links)    [Lane 1]  |  #5 (editor: header presets)  [Lane 2]
Phase 3:  #3 (renderer: card)        [Lane 1]  |  (waiting)                    [Lane 2]
Phase 4:  #4 (renderer: Load More)   [Lane 1]  |  #6 (editor: card controls)   [Lane 2]
Phase 5:  #11 (editor+renderer: btn) [Lane 2]
Phase 6:  #8 (editor: accent)        [Lane 3]  |  #7 (editor: filter/sort)     [Lane 4]
Phase 7:  #9 (editor: preview)       [Lane 3]  |  #10 (editor: photosOnly)     [Lane 4]
```

**Rationale**:
- Phase 1 is the critical path -- all other work depends on having the schema fields defined.
- #1 and #2 are serialized because they both touch `widget.ts`, `embed-renderer.ts`, and `widgetin.ts`.
- In Phase 2, #5 can run in parallel with #2 because #5 only touches `page.tsx` while #2 only touches schema files.
- In Phase 4, #6 can run in parallel with #4 because #6 only touches `page.tsx` while #4 only touches `embed-renderer.ts`.
- From Phase 5 onward, all remaining issues touch `page.tsx`, so they must be carefully sequenced. #11 also touches `widget.ts` and `embed-renderer.ts` but by Phase 5 all schema/renderer work from #1-#4 is complete.
- Phases 6-7 each have two parallel lanes that only conflict on `page.tsx` if run simultaneously. Since each issue in these phases modifies different sections of `page.tsx` (Style tab vs. Settings tab, and preview panel vs. Review tab), there is a small risk of merge conflict on the file level. **Conservative approach**: serialize these too. **Aggressive approach**: run them in parallel accepting minor merge conflicts on import lines. The table above shows the aggressive approach.

### Summary

| # | Title | Type | Priority | Blocked by | Stories | Size | Key files |
|---|-------|------|----------|------------|---------|------|-----------|
| 1 | Add granular card styling and reviewer name format to config schema | AFK | critical | -- | 10,13,15 | medium | `widget.ts`, `embed-renderer.ts`, `widgetin.ts`, `widget.test.ts`, `embed-renderer.test.ts` |
| 2 | Add sort options, Load More config, external link controls, rating format, and branding removal to config schema | AFK | critical | #1 | 5,20,21,22,24 | medium | `widget.ts`, `embed-renderer.ts`, `widgetin.ts`, `widget.test.ts` |
| 3 | Render granular card styles and reviewer name format in embed HTML/CSS | AFK | high | #1 | 10,13,15 | medium | `embed-renderer.ts`, `embed-renderer.test.ts` |
| 4 | Add Load More button, photos-first/random sort, and external link controls to embed | AFK | high | #2 | 5,20,21,22,24 | large | `embed-renderer.ts`, `embed-renderer.test.ts` |
| 5 | Implement header style presets with carousel selector in editor | AFK | normal | #1 | 6,7,14 | medium | `page.tsx` |
| 6 | Add granular card styling controls and name format picker to editor | AFK | normal | #1, #3 | 10,13,15 | medium | `page.tsx` |
| 7 | Add photos-first/random sort, Load More, link controls, rating format, and branding toggle to editor | AFK | normal | #4, #11 | 5,20,21,22,24 | medium | `page.tsx` |
| 8 | Implement accent color palette with preset swatches and custom color picker | AFK | normal | #6 | 17,18 | small | `page.tsx` |
| 9 | Add responsive desktop/mobile toggle to preview panel | AFK | normal | #8 | 23 | small | `page.tsx` |
| 10 | Add photos-only filter toggle end-to-end | AFK | normal | #7 | 19 | small | `embed-renderer.ts`, `page.tsx`, `embed-renderer.test.ts` |
| 11 | Implement granular button styling for Load More and Write Review buttons | AFK | normal | #4, #5 | 16 | medium | `widget.ts`, `embed-renderer.ts`, `page.tsx` |

### User story coverage check

| Story | Issue(s) |
|-------|----------|
| 1. Column counts per breakpoint | Already implemented (responsive config exists) |
| 2. Full-width vs fixed-pixel | Already implemented (responsive.widthMode exists) |
| 3. Row counts and item spacing | Already implemented (responsive.rows, itemSpacing exist) |
| 4. Badge layouts | Already implemented (badge_card, badge_compact, badge_button, badge_request exist) |
| 5. Load More button | #2, #4, #7 |
| 6. Header style presets | #5 |
| 7. Header element toggles | #5 (partial -- toggles already exist, presets enhance them) |
| 8. Card style presets | Already implemented (full/compact/minimal presets exist) |
| 9. Source attribution presets | Already implemented (6 sourceStyle options exist) |
| 10. Reviewer name format | #1, #3, #6 |
| 11. Short/full text display | Already implemented (truncation config exists) |
| 12. Review images, verified badges, owner replies | Already implemented (showPhoto, showOwnerReply exist); verified badges not in current data model (no verified field in reviews table -- out of scope for this PRD) |
| 13. Equal card heights | #1, #3, #6 |
| 14. Header granular styling | #5 (presets), already partially implemented (headerStyle exists) |
| 15. Card granular styling | #1, #3, #6 |
| 16. Button styling | #11 |
| 17. Accent color palette | #8 |
| 18. Stars color + expanded fonts | #8 (stars color already exists, expanded fonts added) |
| 19. Filter: text/photos/keyword/name | #10 (photosOnly); text/keyword/name filters already implemented |
| 20. Sort: photos-first, random | #2, #4, #7 |
| 21. External links + new tab | #2, #4, #7 |
| 22. Rating display format | #2, #4, #7 |
| 23. Desktop/mobile preview toggle | #9 |
| 24. Remove branding | #2, #4, #7 |
