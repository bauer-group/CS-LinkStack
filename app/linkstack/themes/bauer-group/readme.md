# BAUER GROUP — Corporate LinkStack Theme

The corporate "link in bio" theme for BAUER GROUP LinkStack deployments.
It defines the LOOK only — the official palette and font stack. Content such as
the avatar, footer links and the "Powered by LinkStack" credit is NOT part of the
theme; it is managed in the LinkStack admin panel (stored in the data volume) so
it stays editable per deployment.

*	Theme Name: BAUER GROUP
*	Theme Version: 1.0.0
*	Theme Date: 2026-07-16
*	Theme Author: BAUER GROUP
*	Theme Author URI: https://www.bauer-group.com
*	Theme License: Proprietary — © BAUER GROUP (see repository NOTICE)
*	Source code: https://github.com/bauer-group/CS-LinkStack

### Structure
* `config.php` — Theme V2 config (custom-head enabled; body-end disabled).
* `skeleton-auto.css` — original base layout (light/dark via `prefers-color-scheme`).
* `share.button.css` — share button + toast styling.
* `animations.css` — subtle, reduced-motion-aware entrance.
* `extra/custom-head.blade.php` — brand palette (`:root` tokens) + font stack.

### Branding (applied)
* Official BAUER GROUP palette (orange `#FF8500` primary, warm-gray neutrals) in
  `extra/custom-head.blade.php` and `skeleton-auto.css`, light + dark mode, with
  WCAG-AA link text (`#C2570A` / `#FB923C`). Source: CorporateIdentity-BAUERGROUP.
* System-ui font stack per CI — no webfonts required.

### Not part of this theme (managed in the LinkStack admin panel)
* **Avatar / profile logo** — upload the BAUER GROUP logo as the profile picture.
* **Footer links** (Impressum / Datenschutz) — Settings → footer (`DISPLAY_FOOTER_*`),
  labels and targets editable in the admin EnvEditor.
* **"Powered by LinkStack" credit** — disable via `DISPLAY_CREDIT` / `DISPLAY_CREDIT_FOOTER`.

### Optional refinements
* Replace the generated `preview.png` (16:9, ≤ 1920×1080) with a real screenshot.

### Credits
* Base layout is original work by BAUER GROUP, following the LinkStack Theme V2
  contract (https://github.com/LinkStackOrg/linkstack-default-theme).
* Brand tokens © BAUER GROUP (CorporateIdentity-BAUERGROUP).
