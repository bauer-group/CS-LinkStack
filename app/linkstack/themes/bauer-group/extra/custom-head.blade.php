{{--
  BAUER GROUP — Corporate LinkStack Theme
  <head> injection: official BAUER GROUP brand tokens.

  Palette source: CorporateIdentity-BAUERGROUP (docs/de/downloads/css-variablen.md).
  The brand uses a system-ui font stack (no webfonts), so no @font-face is needed.
  Accessibility: link TEXT uses orange-700 (#C2570A, "Text AA") on light and
  orange-400 (#FB923C) on dark; button/accent surfaces use brand orange (#FF8500).
--}}

<style>
  /* ─── BAUER GROUP brand tokens — Light ─────────────────────────────────── */
  :root {
    --bg-brand-primary:        #FF8500;  /* orange-500 — brand primary (buttons/accents) */
    --bg-brand-primary-hover:  #EA6D00;  /* orange-600 — hover / active */
    --bg-brand-accent:         #C2570A;  /* orange-700 — accessible accent */
    --bg-link:                 #C2570A;  /* orange-700 — AA link text on light */

    --bg-page:   #F9F8F6;  /* warm-50  — brand light */
    --bg-text:   #231F1C;  /* warm-900 — brand black */
    --bg-muted:  #6B635C;  /* warm-600 — body text AA */

    --bg-scroll-track: #E0DBD6; /* warm-200 */
    --bg-scroll-thumb: #FF8500; /* orange-500 */

    --bg-font: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
               "Helvetica Neue", Arial, sans-serif;
  }

  /* ─── BAUER GROUP brand tokens — Dark ──────────────────────────────────── */
  @media (prefers-color-scheme: dark) {
    :root {
      --bg-brand-primary:        #FB923C;  /* orange-400 — dark-mode brand */
      --bg-brand-primary-hover:  #FF8500;  /* orange-500 */
      --bg-brand-accent:         #FDBA74;  /* orange-300 */
      --bg-link:                 #FB923C;  /* orange-400 — link text on dark */

      --bg-page:   #231F1C;  /* warm-900 — brand black */
      --bg-text:   #F9F8F6;  /* warm-50 */
      --bg-muted:  #A69E97;  /* warm-400 */

      --bg-scroll-track: #3A3430; /* warm-800 */
      --bg-scroll-thumb: #FB923C; /* orange-400 */
    }
  }

  /* Link text uses the accessible token (buttons keep --bg-brand-primary). */
  a { color: var(--bg-link); }
  a:hover { color: var(--bg-brand-primary-hover); }
</style>
