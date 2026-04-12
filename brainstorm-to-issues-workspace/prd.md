## Problem Statement

The current widget editor offers basic customization (6 layouts, light/dark theme, 5 colors, 8 fonts, simple toggles) but lacks the depth and polish needed to compete with established widget builders like Elfsight. Users cannot fine-tune individual element styles, choose from pre-designed presets, configure responsive breakpoints, or control many common display options. This limits the product's appeal to users who need pixel-perfect control over how reviews appear on their sites.

## Solution

Overhaul the widget editor with comprehensive customization capabilities across layout, header, review cards, theming, filtering, and preview. The goal is to give users Elfsight-level control while keeping the editor intuitive through style presets and organized settings panels.

## User Stories

1. As a widget creator, I want to set column counts per breakpoint (desktop large/medium/small, tablet, mobile), so that my review grid looks great on all screen sizes.
2. As a widget creator, I want to choose between full-width and fixed-pixel widget width, so I can control how the widget fits my page layout.
3. As a widget creator, I want to configure row counts and item spacing, so I can control density and whitespace.
4. As a widget creator, I want to use badge layouts (card badge, compact badge, reviews button, review request), so I can embed compact review indicators on my site.
5. As a widget creator, I want a "Load More" button for pagination, so I can show many reviews without overwhelming the page.
6. As a widget creator, I want to pick from pre-designed header styles, so I can quickly get a polished look without manual tweaking.
7. As a widget creator, I want to toggle individual header elements (heading, rating, review count, write-a-review button, widget title), so I control exactly what appears.
8. As a widget creator, I want to pick from pre-designed review card styles, so I can choose the look that fits my site.
9. As a widget creator, I want to pick from source attribution style presets (icon+name, platform logo, inline badge, etc.), so I control how Google branding appears on each card.
10. As a widget creator, I want to configure reviewer name format (full name, first + last initial, initial + last name), so I can match my site's tone.
11. As a widget creator, I want to choose between short (truncated) and full text display, and control preview text length, so I balance readability and density.
12. As a widget creator, I want to toggle review images, verified badges, and owner replies on cards, so I show exactly the elements I want.
13. As a widget creator, I want to align card heights in grid/row layouts, so my grid looks clean and uniform.
14. As a widget creator, I want granular color/style controls for the header (background, text, logo, corner radius, write-review button styling), so I can match my brand precisely.
15. As a widget creator, I want granular color/style controls for review cards (background, border, text, read-more link, name, date, source icon, source icon background, rating size, text font size, corner radius), so every card element matches my brand.
16. As a widget creator, I want granular button styling (filled/outline style, colors, corner radius, size, font, padding) for both the write-review and load-more buttons, so buttons match my site's design system.
17. As a widget creator, I want an accent color palette with preset colors and a custom picker, so I can quickly set my brand color.
18. As a widget creator, I want the stars color control and expanded font options.
19. As a widget creator, I want to filter reviews to only show those with text, only those with photos, or exclude/include by keyword or reviewer name, so I curate what visitors see.
20. As a widget creator, I want to sort reviews by photos-first or random order (in addition to existing newest/highest/lowest), so I can highlight visual or varied content.
21. As a widget creator, I want to toggle external links and control whether they open in a new tab, so I manage the user flow.
22. As a widget creator, I want to choose the rating display format (e.g., "4.9" vs "4.9/5"), so it matches my preference.
23. As a widget creator, I want a desktop/mobile toggle in the preview panel, so I can see how my widget looks on different devices before publishing.
24. As a premium user, I want to remove the "Powered by Widgetin" branding, so my widget looks fully custom.

## Implementation Decisions

- **Config schema**: Extend the existing widgetConfigSchema Zod object in the widget tRPC route with new nested objects for layout controls, header style, card style, button style, and filter/sort options. All new fields should have sensible defaults for backward compatibility.
- **Presets**: Header presets (~5-10) and card presets (~3) + source presets (~6) are predefined config objects stored as constants. Selecting a preset applies its values to the relevant config section. Users can then further customize.
- **Badge layouts**: Add 4 new layout type values (badge_card, badge_compact, badge_button, badge_request). Each gets its own HTML/CSS template in the embed renderer.
- **Responsive columns**: Use CSS media queries with the 5 breakpoints (>=1900, >=1400, >=1024, >=778, >=480). Column config stored as an object with keys for each breakpoint.
- **Load More**: Implement client-side pagination in the embed HTML. Reviews are all included in the HTML but hidden beyond page 1, with a button to reveal more.
- **Embed renderer**: All new styling flows through the existing embed-renderer.ts service. New config fields map to CSS custom properties or inline styles in the generated HTML.
- **Editor UI**: Extend the existing tabbed editor. Group granular styling controls under collapsible sections within the Style tab. Presets get carousel selectors in their respective tabs.
- **Backward compatibility**: All new config fields are optional with defaults matching current behavior, so existing widgets render identically without migration.
