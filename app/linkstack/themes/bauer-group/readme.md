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

### Placeholders to replace before go-live
* Brand hex values in `extra/custom-head.blade.php` (`--bg-brand-*`).
* Corporate `.woff2` fonts in `extra/custom-assets/` (+ uncomment `@font-face`).
* `preview.png` (16:9, ≤ 1920×1080).
* Footer legal URLs in `extra/custom-body-end.blade.php`.

### Credits
* Base layout is original work by BAUER GROUP, following the LinkStack Theme V2
  contract (https://github.com/LinkStackOrg/linkstack-default-theme).
