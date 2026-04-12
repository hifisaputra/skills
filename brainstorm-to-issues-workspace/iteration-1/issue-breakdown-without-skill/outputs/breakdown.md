# Widget Editor Enhancement -- Issue Breakdown

## Pre-analysis: What already exists vs. what the PRD requires

The codebase already implements a significant portion of the PRD. The following are **already implemented**: badge layouts, responsive columns with breakpoints, widget width modes, row counts and item spacing, header element toggles, card presets (full/compact/minimal), source attribution styles, text truncation, review card element toggles (photo, date, source, owner reply), header style controls (background, text, logo color, corner radius, write-review button styling), stars color, text-only filter, exclude/include keyword/name rules, basic 8-font selection, and light/dark theme with basic colors. The embed renderer already removes "Powered by Widgetin" for non-free plans.

The issues below cover only the **gaps** between the PRD and the current codebase.

---

## Issue 1: Desktop/Mobile Preview Toggle in Editor

**Title:** Add desktop/mobile preview toggle to widget editor

**Description:**
Add a toggle in the widget editor preview panel that allows switching between desktop and mobile viewport sizes. Currently the preview iframe is always shown at full available width. Add a toolbar above the preview with desktop/tablet/mobile buttons that resize the iframe to simulate those viewports (e.g., desktop = 100%, tablet = 768px, mobile = 375px).

**Acceptance Criteria:**
- A toggle bar with Desktop, Tablet, Mobile buttons appears above the preview iframe in the editor page
- Clicking Mobile resizes the iframe container to 375px width (centered)
- Clicking Tablet resizes the iframe container to 768px width (centered)
- Clicking Desktop restores the iframe to fill available space
- Selected device is visually indicated (highlighted button)
- Preview iframe re-renders correctly at each size

**Dependencies:** None

**Estimated Size:** Small

**Type:** AFK

**Files to modify:**
- `/tmp/widgetin/src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` -- add preview toolbar and state

---

## Issue 2: Expanded Font Options

**Title:** Expand font selection with more Google Fonts options

**Description:**
The current editor offers 8 fonts. Extend this to ~20+ fonts including popular choices (Raleway, Playfair Display, Oswald, Merriweather, Libre Baskerville, DM Sans, Work Sans, Outfit, Space Grotesk, etc.). Also ensure the embed renderer loads the selected Google Font in the rendered HTML `<head>`.

**Acceptance Criteria:**
- Font dropdown in the Style tab offers at least 20 font options
- Selected font is loaded via Google Fonts `<link>` tag in the embed HTML output
- Preview updates with the correct font when changed
- Existing widgets with the original 8 fonts continue working without change

**Dependencies:** None

**Estimated Size:** Small

**Type:** AFK

**Files to modify:**
- `/tmp/widgetin/src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` -- expand `FONT_OPTIONS` array
- `/tmp/widgetin/src/server/services/embed-renderer.ts` -- add Google Fonts `<link>` tag to HTML head
- `/tmp/widgetin/src/server/services/embed-renderer.test.ts` -- add test for font link rendering

---

## Issue 3: Reviewer Name Format Configuration

**Title:** Add reviewer name format options to review card settings

**Description:**
Allow users to choose how reviewer names are displayed: full name (default, current behavior), first name + last initial (e.g., "Budi S."), or first initial + last name (e.g., "B. Santoso"). Add a `nameFormat` field to the `reviewCard` config object and implement the formatting in the embed renderer.

**Acceptance Criteria:**
- New `nameFormat` field added to `widgetConfigSchema.reviewCard` with values: `"full"`, `"first_last_initial"`, `"initial_last_name"`
- Default is `"full"` for backward compatibility
- Embed renderer applies the format when rendering reviewer names
- Editor UI shows a dropdown/selector in the Review tab for name format
- Unit tests cover all three format variants

**Dependencies:** None

**Estimated Size:** Small

**Type:** AFK

**Files to modify:**
- `/tmp/widgetin/src/server/api/routes/widget.ts` -- add `nameFormat` to `widgetConfigSchema.reviewCard`
- `/tmp/widgetin/src/server/services/embed-renderer.ts` -- add `WidgetConfig` type field, implement name formatting in `renderReviewCard`
- `/tmp/widgetin/src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` -- add name format selector UI in Review tab
- `/tmp/widgetin/src/server/services/embed-renderer.test.ts` -- add tests
- `/tmp/widgetin/src/server/db/schema/widgetin.ts` -- update default config JSON

---

## Issue 4: Photos-Only Filter and Sort by Photos-First / Random

**Title:** Add photos-only filter and photos-first/random sort options

**Description:**
The PRD requests: (1) a "photos only" filter toggle (only show reviews that have photos), (2) a "photos first" sort option, and (3) a "random" sort option. The `photosOnly` filter field already exists in the schema but is not wired up in the editor UI or fully in the renderer. The sort options need to be extended from `["newest", "highest", "lowest"]` to include `"photos_first"` and `"random"`.

Note: The current `EmbedReview` interface does not have a photos/images field. Since reviews are scraped from Google via Outscraper, this issue also includes adding a `reviewImages` field to track review photos if not already present. If the Outscraper data doesn't include images, the `photosOnly` and `photos_first` features should gracefully degrade (no reviews shown / sort has no effect).

**Acceptance Criteria:**
- `photosOnly` toggle appears in the Advanced Filters section of the Review tab in the editor
- `sortBy` enum in `widgetConfigSchema` includes `"photos_first"` and `"random"`
- Sort dropdown in the Review tab includes "Foto Dulu" (photos first) and "Acak" (random) options
- `filterAndSortReviews` in embed-renderer handles `photosOnly` and the two new sort modes
- Random sort uses a deterministic seed per page load (so the embed HTML is cacheable within a cache window)
- Unit tests cover new filter and sort behaviors

**Dependencies:** None

**Estimated Size:** Medium

**Type:** AFK

**Files to modify:**
- `/tmp/widgetin/src/server/api/routes/widget.ts` -- extend `sortBy` enum
- `/tmp/widgetin/src/server/services/embed-renderer.ts` -- update `WidgetConfig`, `filterAndSortReviews` logic
- `/tmp/widgetin/src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` -- add `photosOnly` toggle, update `SORT_OPTIONS`
- `/tmp/widgetin/src/server/services/embed-renderer.test.ts` -- tests
- `/tmp/widgetin/src/server/db/schema/widgetin.ts` -- update default config if needed

---

## Issue 5: Granular Review Card Style Controls

**Title:** Add granular color and style controls for review cards

**Description:**
Add a `cardStyle` config section with granular controls for review card appearance: card background color, card border color, card text color, read-more link color, reviewer name color, date color, source icon color, source icon background color, star rating size, review text font size, and card-specific corner radius. These map to CSS custom properties or inline styles in the embed renderer.

**Acceptance Criteria:**
- New `cardStyle` optional object added to `widgetConfigSchema` with fields: `backgroundColor`, `borderColor`, `textColor`, `readMoreColor`, `nameColor`, `dateColor`, `sourceIconColor`, `sourceIconBgColor`, `ratingSize` (number, px), `textFontSize` (number, px), `cornerRadius` (number, px)
- All fields are optional with no defaults (falls back to existing theme behavior)
- Embed renderer maps these to CSS custom properties and applies them
- Style tab in editor shows a collapsible "Card Styles" section with color pickers and sliders for each property
- Existing widgets render identically (all fields optional)
- Unit tests verify CSS custom property output

**Dependencies:** None

**Estimated Size:** Medium

**Type:** AFK

**Files to modify:**
- `/tmp/widgetin/src/server/api/routes/widget.ts` -- add `cardStyle` to schema
- `/tmp/widgetin/src/server/services/embed-renderer.ts` -- add type fields, CSS custom properties, inline styles
- `/tmp/widgetin/src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` -- add Card Styles collapsible section in Style tab
- `/tmp/widgetin/src/server/services/embed-renderer.test.ts` -- tests

---

## Issue 6: Accent Color Palette with Presets

**Title:** Add accent color palette with preset colors and custom picker

**Description:**
Add a quick-pick accent color palette at the top of the Style > Colors section. Show ~8 preset color swatches (e.g., blue, red, green, orange, purple, teal, pink, slate) that set the primary color with one click. Include the existing color picker for custom colors. This is a UI-only enhancement -- the primary color field already exists in the config.

**Acceptance Criteria:**
- A row of ~8 color swatches appears above the primary color picker in the Style tab
- Clicking a swatch sets `colors.primary` to that preset color
- The currently active preset (or none if custom) is visually highlighted
- The custom color picker remains available for arbitrary colors
- No schema changes needed

**Dependencies:** None

**Estimated Size:** Small

**Type:** AFK

**Files to modify:**
- `/tmp/widgetin/src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` -- add preset color swatches UI

---

## Issue 7: Header Style Presets

**Title:** Add pre-designed header style presets

**Description:**
Create 5-8 pre-designed header style presets (e.g., "Default", "Bold", "Minimal", "Centered", "Dark Bar", "Rounded Card", "Gradient") that bundle header configuration values (background color, text color, corner radius, button variant/size). Selecting a preset applies its config values to `header` and `headerStyle`. Users can further customize after applying a preset.

**Acceptance Criteria:**
- A `HEADER_PRESETS` constant array is defined with 5-8 presets, each containing `header` and `headerStyle` values
- A horizontal carousel/grid of preset thumbnails/labels appears at the top of the Header tab
- Clicking a preset applies its values to the current config's `header` and `headerStyle` sections
- User can further customize after applying a preset
- No schema changes needed (presets are UI-only mappings to existing fields)

**Dependencies:** None

**Estimated Size:** Small

**Type:** HITL (preset designs require design review/approval)

**Files to modify:**
- `/tmp/widgetin/src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` -- add `HEADER_PRESETS` constant and preset selector UI in Header tab

---

## Issue 8: Card Height Alignment in Grid/Masonry Layouts

**Title:** Add equal card height toggle for grid layout

**Description:**
Add an `equalHeight` toggle to the responsive config. When enabled in grid layout, all review cards in a row are stretched to the same height (using CSS `align-items: stretch` on the grid container and `height: 100%` on cards). This ensures a clean, uniform grid appearance.

**Acceptance Criteria:**
- New `equalHeight` boolean field (default `false`) added to `widgetConfigSchema.responsive`
- When enabled, grid layout cards stretch to equal row height
- Toggle appears in the Layout tab under the Grid section
- Masonry layout is unaffected (inherently variable height)
- Existing widgets unaffected (defaults to `false`)
- CSS is added to embed renderer for the equal-height mode

**Dependencies:** None

**Estimated Size:** Small

**Type:** AFK

**Files to modify:**
- `/tmp/widgetin/src/server/api/routes/widget.ts` -- add `equalHeight` to responsive schema
- `/tmp/widgetin/src/server/services/embed-renderer.ts` -- add CSS for equal height, update type
- `/tmp/widgetin/src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` -- add toggle in Layout tab

---

## Issue 9: Load More Button Pagination

**Title:** Implement client-side "Load More" pagination for grid/list/masonry layouts

**Description:**
Per the PRD, implement client-side pagination with a "Load More" button. All reviews are included in the HTML but hidden beyond the first page. Add a `pagination` config section with `enabled` (boolean), `pageSize` (number), and styling fields. The embed renderer hides reviews beyond the first page and adds a "Load More" button with JavaScript to reveal the next batch.

**Acceptance Criteria:**
- New `pagination` optional object in `widgetConfigSchema`: `enabled` (boolean, default false), `pageSize` (number, default 6, min 3 max 50)
- Embed renderer wraps reviews in page groups; only the first group is visible initially
- A "Muat Lebih Banyak" button appears below the reviews container
- Clicking the button reveals the next page of reviews (vanilla JS, no framework)
- Button disappears when all reviews are shown
- Pagination only applies to grid, list, and masonry layouts
- Editor shows pagination toggle and page size input in the Layout tab
- Unit tests verify hidden reviews and button presence in HTML output

**Dependencies:** None

**Estimated Size:** Medium

**Type:** AFK

**Files to modify:**
- `/tmp/widgetin/src/server/api/routes/widget.ts` -- add `pagination` to schema
- `/tmp/widgetin/src/server/services/embed-renderer.ts` -- update type, modify grid/list/masonry rendering, add JS
- `/tmp/widgetin/src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` -- add pagination controls in Layout tab
- `/tmp/widgetin/src/server/services/embed-renderer.test.ts` -- tests

---

## Issue 10: Load More Button Styling Controls

**Title:** Add granular styling controls for the Load More button

**Description:**
Add a `loadMoreStyle` config section for styling the Load More button: variant (filled/outline), background color, text color, corner radius, font size, padding. This mirrors the existing write-review button styling. Wire it into the embed renderer.

**Acceptance Criteria:**
- New `loadMoreStyle` optional object in `widgetConfigSchema` with same shape as `headerStyle.button`
- Embed renderer applies these styles to the Load More button as inline styles
- Style tab shows "Load More Button" section (only when pagination is enabled)
- Defaults match the primary color theme

**Dependencies:** Issue 9 (Load More Button Pagination)

**Estimated Size:** Small

**Type:** AFK

**Files to modify:**
- `/tmp/widgetin/src/server/api/routes/widget.ts` -- add `loadMoreStyle` to schema
- `/tmp/widgetin/src/server/services/embed-renderer.ts` -- apply inline styles to Load More button
- `/tmp/widgetin/src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` -- add button style controls in Style tab

---

## Issue 11: Rating Display Format Configuration

**Title:** Add rating display format option (e.g., "4.9" vs "4.9/5")

**Description:**
Allow users to choose how the average rating is displayed in the header: just the number (e.g., "4.9"), number with max (e.g., "4.9/5"), or with text (e.g., "4.9 out of 5"). Add a `ratingFormat` field to the header config.

**Acceptance Criteria:**
- New `ratingFormat` field in `widgetConfigSchema.header` with values: `"number"` (default, shows "4.9"), `"fraction"` (shows "4.9/5"), `"text"` (shows "4.9 out of 5")
- Default is `"number"` for backward compatibility
- Embed renderer applies the format in `renderHeader`
- Editor shows a dropdown in the Header tab for rating format
- Unit tests cover all three formats

**Dependencies:** None

**Estimated Size:** Small

**Type:** AFK

**Files to modify:**
- `/tmp/widgetin/src/server/api/routes/widget.ts` -- add `ratingFormat` to header schema
- `/tmp/widgetin/src/server/services/embed-renderer.ts` -- update type and `renderHeader`
- `/tmp/widgetin/src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` -- add dropdown in Header tab
- `/tmp/widgetin/src/server/services/embed-renderer.test.ts` -- tests
- `/tmp/widgetin/src/server/db/schema/widgetin.ts` -- update default config JSON

---

## Issue 12: External Links Toggle and New Tab Control

**Title:** Add toggle for external links and target behavior

**Description:**
Add controls to toggle whether external links (Google review links, write-review links, powered-by link) appear, and whether they open in a new tab or the same tab. Add `externalLinks` config section with `enabled` (boolean) and `openInNewTab` (boolean).

**Acceptance Criteria:**
- New `externalLinks` optional object in `widgetConfigSchema`: `enabled` (boolean, default true), `openInNewTab` (boolean, default true)
- When `enabled` is false, all external links in the embed are rendered as plain text (no `<a>` tags)
- When `openInNewTab` is false, links use `target="_self"` instead of `target="_blank"`
- Settings tab in editor shows toggles for these two options
- Existing widgets unaffected (defaults match current behavior)
- Unit tests cover link rendering with both settings

**Dependencies:** None

**Estimated Size:** Small

**Type:** AFK

**Files to modify:**
- `/tmp/widgetin/src/server/api/routes/widget.ts` -- add `externalLinks` to schema
- `/tmp/widgetin/src/server/services/embed-renderer.ts` -- conditional link rendering
- `/tmp/widgetin/src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` -- add toggles in Settings tab
- `/tmp/widgetin/src/server/services/embed-renderer.test.ts` -- tests

---

## Issue 13: Verified Badge Toggle on Review Cards

**Title:** Add verified badge toggle to review card settings

**Description:**
Add a `showVerifiedBadge` toggle to the review card config. When enabled, display a small "Verified" badge or checkmark icon next to the reviewer name for reviews that are verified purchases/visits. Since Google reviews don't have a direct "verified" field from Outscraper, this badge would show for all reviews from Google (indicating they are verified Google reviews). This could later be extended when other review sources are added.

**Acceptance Criteria:**
- New `showVerifiedBadge` boolean field in `widgetConfigSchema.reviewCard` (default `false`)
- Embed renderer shows a small verified badge (checkmark + "Terverifikasi" text) next to reviewer name when enabled
- CSS styling for the verified badge is included in the embed CSS
- Toggle appears in the Review tab's card element toggles
- Default is `false` for backward compatibility

**Dependencies:** None

**Estimated Size:** Small

**Type:** AFK

**Files to modify:**
- `/tmp/widgetin/src/server/api/routes/widget.ts` -- add `showVerifiedBadge` to reviewCard schema
- `/tmp/widgetin/src/server/services/embed-renderer.ts` -- render verified badge HTML and CSS
- `/tmp/widgetin/src/app/(dashboard)/dashboard/widgets/[id]/page.tsx` -- add toggle in Review tab

---

## Summary Table

| # | Title | Size | Type | Depends On |
|---|-------|------|------|------------|
| 1 | Desktop/Mobile Preview Toggle | Small | AFK | -- |
| 2 | Expanded Font Options | Small | AFK | -- |
| 3 | Reviewer Name Format | Small | AFK | -- |
| 4 | Photos-Only Filter + Photos-First/Random Sort | Medium | AFK | -- |
| 5 | Granular Review Card Style Controls | Medium | AFK | -- |
| 6 | Accent Color Palette with Presets | Small | AFK | -- |
| 7 | Header Style Presets | Small | HITL | -- |
| 8 | Card Height Alignment (Equal Height Toggle) | Small | AFK | -- |
| 9 | Load More Button Pagination | Medium | AFK | -- |
| 10 | Load More Button Styling | Small | AFK | 9 |
| 11 | Rating Display Format | Small | AFK | -- |
| 12 | External Links Toggle + New Tab Control | Small | AFK | -- |
| 13 | Verified Badge Toggle | Small | AFK | -- |

**Total: 13 issues (9 Small, 3 Medium, 1 HITL)**

## Suggested Implementation Order

1. **Issue 1** (Preview Toggle) -- unblocks design validation for all subsequent work
2. **Issue 2** (Fonts) -- standalone, quick win
3. **Issue 3** (Name Format) -- standalone, quick win
4. **Issue 6** (Accent Palette) -- UI-only, no schema changes
5. **Issue 11** (Rating Format) -- small schema + renderer change
6. **Issue 12** (External Links) -- small schema + renderer change
7. **Issue 13** (Verified Badge) -- small schema + renderer change
8. **Issue 8** (Equal Height) -- small schema + CSS change
9. **Issue 4** (Photos Filter/Sort) -- medium, extends filtering logic
10. **Issue 5** (Card Style Controls) -- medium, many new CSS properties
11. **Issue 7** (Header Presets) -- needs design input (HITL)
12. **Issue 9** (Load More Pagination) -- medium, new JS in embed
13. **Issue 10** (Load More Styling) -- depends on Issue 9
