# Analytics

Every Claude app on **`dwightexmachina.github.io`** shares **one** Cloudflare
Web Analytics beacon → a single dashboard. You tell projects apart by filtering
on the URL path (`/skylark/`, `/mindyourlanguage/`, `/sirmixalot/`, …).

Dashboard: Cloudflare → **Analytics & Logs → Web Analytics → dwightexmachina.github.io**

## The snippet (already in `web/index.html`, before `</body>`)

```html
<!-- Cloudflare Web Analytics -->
<script defer src="https://static.cloudflareinsights.com/beacon.min.js"
        data-cf-beacon='{"token": "e1ce906b719c4a2a86e327fa6d916f77"}'></script>
<!-- End Cloudflare Web Analytics -->
```

## Adding analytics to a NEW app on this host
1. Paste the snippet above before `</body>` in the new app's `web/index.html`.
2. Build & deploy. It shows up in the same dashboard — filter by its path.

Notes:
- The token is a **public identifier** (it ships in the page HTML), not a secret.
- Client beacons are blocked by some ad-blockers, so counts are a lower bound.
- `web/index.html` is a Flutter build *template*, so the snippet survives every
  `flutter build web`.
