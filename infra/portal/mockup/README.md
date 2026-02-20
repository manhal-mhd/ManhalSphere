ManhalSphere Portal — Static mockup

Files:
- index.html — static mockup of the portal UI
- styles.css — styling for the mockup

Preview:
1. Open `infra/portal/mockup/index.html` in a browser, or run a simple server:

```bash
cd infra/portal/mockup
python3 -m http.server 8000
# then open http://localhost:8000
```

Notes & next steps:
- Icons are simple emoji placeholders for the mockup; I can replace these with inline SVGs or a curated Heroicons set for consistent visuals.
- After you confirm the layout and color scheme, I can integrate the styles into the live portal template and wire the config entries to use local SVG assets.
