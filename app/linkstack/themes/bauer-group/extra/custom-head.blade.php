{{--
  BAUER GROUP — Corporate LinkStack Theme
  <head> injection: corporate fonts + brand colour tokens.

  ┌─────────────────────────────────────────────────────────────────────────┐
  │  ⚠  PLACEHOLDER VALUES — replace with the official BAUER GROUP assets:    │
  │     1. Drop the corporate .woff2 files into  extra/custom-assets/         │
  │     2. Replace the :root hex values below with the official palette       │
  │     3. Update the preview.png (16:9, ≤ 1920×1080)                          │
  │  Assets are referenced with LinkStack's {{ themeAsset('file') }} helper.  │
  └─────────────────────────────────────────────────────────────────────────┘
--}}

{{-- Corporate webfont — uncomment once the .woff2 files exist in custom-assets/
<style>
@font-face {
  font-family: 'BAUER GROUP Sans';
  font-style: normal; font-weight: 400; font-display: swap;
  src: url('{{ themeAsset('corporate-400.woff2') }}') format('woff2');
}
@font-face {
  font-family: 'BAUER GROUP Sans';
  font-style: normal; font-weight: 700; font-display: swap;
  src: url('{{ themeAsset('corporate-700.woff2') }}') format('woff2');
}
</style>
--}}

<style>
  /* Official BAUER GROUP palette — REPLACE the placeholder hex values. */
  :root {
    --bg-brand-primary:        #0a3d62;   /* PLACEHOLDER — corporate primary   */
    --bg-brand-primary-hover:  #1e6091;   /* PLACEHOLDER — hover / active       */
    --bg-brand-accent:         #e58e26;   /* PLACEHOLDER — accent / highlight    */

    /* Enable once the corporate webfont is provided:
    --bg-font: 'BAUER GROUP Sans', system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif;
    */
  }
</style>
