# BAUER GROUP — Corporate LinkStack Theme

The corporate "link in bio" theme for BAUER GROUP LinkStack deployments.
Provides a clean, modern base layout that consumes CSS custom properties, so the
official palette, fonts and footer are applied through the custom-code injection
points in `extra/` without touching the base CSS.

*	Theme Name: BAUER GROUP
*	Theme Version: 1.0.0
*	Theme Date: 2026-07-16
*	Theme Author: BAUER GROUP
*	Theme Author URI: https://www.bauer-group.com
*	Theme License: Proprietary — © BAUER GROUP (see repository NOTICE)
*	Source code: https://github.com/bauer-group/CS-LinkStack

### Structure
* `config.php` — Theme V2 config (custom-code enabled).
* `skeleton-auto.css` — original base layout (light/dark via `prefers-color-scheme`).
* `share.button.css` — share button + toast styling.
* `animations.css` — subtle, reduced-motion-aware entrance.
* `extra/custom-head.blade.php` — **swap-in point** for the brand palette + webfonts.
* `extra/custom-body-end.blade.php` — corporate footer (Impressum / Datenschutz).
* `extra/custom-assets/` — corporate webfonts / images (referenced via `themeAsset()`).

### Branding (applied)
* Official BAUER GROUP palette (orange `#FF8500` primary, warm-gray neutrals) in
  `extra/custom-head.blade.php` and `skeleton-auto.css`, light + dark mode, with
  WCAG-AA link text (`#C2570A` / `#FB923C`). Source: CorporateIdentity-BAUERGROUP.
* System-ui font stack per CI — no webfonts required.
* Corporate logo(s) bundled in `extra/custom-assets/` and shown in the footer.

### Optional refinements
* Replace the generated `preview.png` (16:9, ≤ 1920×1080) with a real screenshot.
* Confirm the footer Impressum / Datenschutz URLs for the target deployment.

### Credits
* Base layout is original work by BAUER GROUP, following the LinkStack Theme V2
  contract (https://github.com/LinkStackOrg/linkstack-default-theme).
* Brand tokens and logo © BAUER GROUP (CorporateIdentity-BAUERGROUP).
