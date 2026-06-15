# dynamicalsystemsgroup.github.io

Showcase of interactive demonstrations hosted under
`dynamicalsystemsgroup.github.io`. Served as a static GitHub Pages site from
[`index.html`](index.html).

Built on the [DSG design system](../dsg-design-system): navy/brass bookends,
Source Serif 4 + JetBrains Mono, square corners, hairline rules, no shadows.
Token values are inlined in `index.html` so the page is self-contained.

## Structure

```text
index.html              # the showcase page
assets/
  logos/                # brass-on-navy lockup (navbar/footer)
  favicons/             # light / dark / webclip
  screenshots/          # one image per demo (16:10-ish)
```

## Adding a demo

1. Capture a screenshot into `assets/screenshots/<demo>.png` (aim for a
   16:10-ish crop of meaningful content). A headless capture works:

   ```sh
   "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
     --headless=new --hide-scrollbars --force-device-scale-factor=2 \
     --window-size=1280,800 --virtual-time-budget=8000 \
     --screenshot=assets/screenshots/<demo>.png \
     "https://dynamicalsystemsgroup.github.io/<demo>/"
   ```

2. Copy one `<article class="demo-card-wrap">` block in `index.html`, then
   update the `href`, the screenshot `src`, the eyebrow, title, and
   description. Bump the `02 hosted` count.

Copy must follow the DSG voice rules — see
[`../dsg-design-system/voice/what-not-to-say.md`](../dsg-design-system/voice/what-not-to-say.md).
Calm, technical, no marketing intensifiers, no exclamation marks.
