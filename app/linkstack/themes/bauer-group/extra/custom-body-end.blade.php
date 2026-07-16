{{-- BAUER GROUP — Corporate LinkStack Theme
     End-of-body injection: corporate logo + footer with legal links.
     ⚠ Confirm the Impressum / Datenschutz URLs for your deployment. --}}

<footer style="text-align:center;margin:2.5rem auto 0;max-width:600px;
               font-size:.8rem;line-height:1.6;color:var(--bg-muted);">
  <img src="{{ themeAsset('bauer-group-logo.svg') }}" alt="BAUER GROUP"
       width="40" height="40" loading="lazy"
       style="display:block;margin:0 auto .6rem;" />
  <a href="https://www.bauer-group.com/impressum" target="_blank" rel="noopener noreferrer"
     style="color:var(--bg-muted);text-decoration:none;">Impressum</a>
  <span aria-hidden="true">·</span>
  <a href="https://www.bauer-group.com/datenschutz" target="_blank" rel="noopener noreferrer"
     style="color:var(--bg-muted);text-decoration:none;">Datenschutz</a>
  <div style="margin-top:.4rem;">&copy; {{ date('Y') }} BAUER GROUP</div>
</footer>
