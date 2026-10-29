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

`docker build` copies the files into the image, so an image built before an edit still serves the old page. While editing,
mount the folder instead and just refresh the browser (the server caches for five minutes, so use a hard refresh,
Ctrl+Shift+R):
```
docker run --rm -p 8080:8080 -v "$PWD/public:/srv:ro" -v "$PWD/Caddyfile:/etc/caddy/Caddyfile:ro" caddy:2-alpine
```

## Deploy on Railway
1. New project, Deploy from GitHub repo, pick this repo. Railway finds the `Dockerfile` (see `railway.toml`).
2. In the service, Settings, Networking: Generate Domain. That gives a public HTTPS address straight away.
3. For a company address (suggested `privacy.verlet.co`): Settings, Networking, Custom Domain. Railway shows a CNAME
   target; add it as a CNAME record for `privacy` in the DNS provider (Cloudflare), then wait for the certificate.
   If the record is proxied in Cloudflare and the certificate does not issue, switch it to DNS only.
4. Open `https://privacy.verlet.co/ego/` in a private window on a phone. It must load with no login.

### Deploying from your computer with the Railway CLI (no GitHub access needed)
Use this when Railway's GitHub app cannot see the repo.

Install once. On WSL or Linux, a plain `npm i -g` fails with `EACCES` because Node lives in a root-owned folder, so
install into your own folder instead (no `sudo`):
```
npm config set prefix ~/.npm-global
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
npm i -g @railway/cli
railway --version
```
Then, from this folder:
```
railway login --browserless              # prints a link and a code; open the link in any browser
railway init --name verlet-legal         # add --workspace <name> if you belong to more than one
railway add --service verlet-legal       # an empty service for the code
railway up --service verlet-legal        # uploads this folder and builds the Dockerfile
railway domain                           # generates a public *.up.railway.app address
railway domain privacy.verlet.co         # custom domain; prints the CNAME record to add in DNS
```
A CLI deploy is not linked to GitHub, so pushing a change does not redeploy it. After the first setup, deploy every change
with the script, which does the copy, the safety checks, the upload and the check that the live site matches:
```
bash deploy.sh              # deploy
bash deploy.sh --dry-run    # every check and the copy, but no upload
bash deploy.sh --verify-only   # only compare https://privacy.verlet.co with this folder
```
It copies the folder to your Linux disk first on purpose: uploading straight from a Windows drive (`/mnt/c`) made
Railway's builder report NUL bytes in plain files. These commands were checked against `railway --help` (CLI 5.71).

The same `public/` folder also deploys unchanged to Cloudflare Pages or any static host.

## Changing a policy
1. Edit the page in `public/<product>/index.html`.
2. Change "Last updated" at the top of the page, and "Effective" if the change takes effect later.
3. Add a line to `CHANGELOG.md`: the date, what changed and why, and who approved it.
4. Open a pull request and merge it.
5. Deploy with `bash deploy.sh` (merging does not deploy by itself).

## Adding a policy
Create `public/<name>/index.html` (copy `public/ego/index.html` as a starting point), then add a link in
`public/index.html`. If there are ever more than a few pages, move the shared CSS into one file; until then each page
stays self-contained on purpose, and the strict `Content-Security-Policy` in the `Caddyfile` only allows inline styles.
