<?php

/*
|--------------------------------------------------------------------------
| BAUER GROUP — Corporate LinkStack Theme (Theme V2)
|--------------------------------------------------------------------------
|
| Brand colours, fonts and footer live in extra/custom-head.blade.php and
| extra/custom-body-end.blade.php (LinkStack's custom-code injection points).
| The base layout is provided by skeleton-auto.css and consumes CSS custom
| properties (--bg-brand-*) so the theme renders with neutral defaults even
| before the corporate assets are dropped in.
|
| See app/linkstack/themes/themes.lock.json and NOTICE for licensing.
|
*/

return [

    // Buttons created with the Button Editor are allowed.
    'allow_custom_buttons' => 'true',

    // Open link targets in a new tab.
    'open_links_in_same_tab' => 'false',

    // Use LinkStack's default button styling (no brands.css required). Brand
    // accent colours are applied on top via extra/custom-head.blade.php.
    'use_default_buttons' => 'true',

    // Enable custom-code injection — this is how the corporate branding
    // (fonts, colours, footer) is applied.
    'enable_custom_code' => 'true',

    'enable_custom_head'     => 'true',   // fonts + :root brand variables
    'enable_custom_body'     => 'false',  // not used
    'enable_custom_body_end' => 'true',   // corporate footer (Impressum/Datenschutz)

    // No custom icon set shipped with the corporate theme.
    'use_custom_icons' => 'false',
    'custom_icon_extension' => '.svg',

];
