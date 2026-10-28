# verlet-legal

The public legal pages for Verlet Robotics products, as plain static files.

| URL path | Page |
|---|---|
| `/` | Index of policies |
| `/ego/` | Verlet Ego privacy policy |

## How it works
`public/` is served as is by Caddy (`Caddyfile`) in a small container (`Dockerfile`). There is no build step, no
framework and no JavaScript. Each page is one self-contained HTML file, so a page can be copied anywhere.

## Run it locally
```
docker build -t verlet-legal .
docker run --rm -p 8080:8080 verlet-legal
```
Then open http://localhost:8080/ego/

## Deploy on Railway
1. New project, Deploy from GitHub repo, pick this repo. Railway finds the `Dockerfile` (see `railway.toml`).
2. In the service, Settings, Networking: Generate Domain. That gives a public HTTPS address straight away.
3. For a company address (suggested `privacy.verlet.co`): Settings, Networking, Custom Domain. Railway shows a CNAME
   target; add it as a CNAME record for `privacy` in the DNS provider (Cloudflare), then wait for the certificate.
   If the record is proxied in Cloudflare and the certificate does not issue, switch it to DNS only.
4. Open `https://privacy.verlet.co/ego/` in a private window on a phone. It must load with no login.

The same `public/` folder also deploys unchanged to Cloudflare Pages or any static host.

## Changing a policy
1. Edit the page in `public/<product>/index.html`.
2. Change "Last updated" at the top of the page, and "Effective" if the change takes effect later.
3. Add a line to `CHANGELOG.md`: the date, what changed and why, and who approved it.
4. Open a pull request. Merging to the main branch redeploys.

## Adding a policy
Create `public/<name>/index.html` (copy `public/ego/index.html` as a starting point), then add a link in
`public/index.html`. If there are ever more than a few pages, move the shared CSS into one file; until then each page
stays self-contained on purpose, and the strict `Content-Security-Policy` in the `Caddyfile` only allows inline styles.
