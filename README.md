# GoDaddy DDNS for Synology SRM

A Synology Router Manager (SRM) package that keeps GoDaddy DNS **A records**
pointed at your router's current public IP — dynamic-DNS for domains hosted at
GoDaddy, running directly on the router (RT1900ac / RT2600ac / RT6600ax /
WRX560, any model — the package is `noarch` shell script only).

## How it works

- A tiny daemon (started/stopped by Package Center) wakes every
  `CHECK_INTERVAL` seconds (default 5 min).
- It looks up the public IP (ipify → AWS checkip → ifconfig.me fallbacks).
- If the IP changed since the last successful update, it `PUT`s the new IP to
  the GoDaddy API for each configured record:
  `PUT https://api.godaddy.com/v1/domains/<domain>/records/A/<name>`
- Logs to `/var/packages/godaddy-ddns/target/var/godaddy-ddns.log`
  (auto-rotated at 256 KB).

## GoDaddy API access

Per [GoDaddy's API access policy](https://www.godaddy.com/help/how-do-i-access-domain-related-apis-42424),
any account with **at least one active domain** gets Domains API access with a
20,000 calls/month limit — vastly more than this package uses, since it only
calls GoDaddy when the public IP actually changes. (During 2024 GoDaddy
temporarily restricted the API to large accounts, which older forum threads
still reference; the current policy above supersedes that.)

Quick sanity check for your credentials before installing (read-only):

```sh
curl -s -w '\nHTTP %{http_code}\n' \
  -H "Authorization: sso-key YOUR_KEY:YOUR_SECRET" \
  "https://api.godaddy.com/v1/domains/yourdomain.com/records/A/@"
```

HTTP 200 means you're good to go.

## Build

```sh
./build.sh            # -> dist/godaddy-ddns-1.0.0.spk
./build.sh 1.1.0      # override version
```

Build on macOS/Linux; needs only `tar`, `sed`, `md5`/`md5sum`, `python3`
(icons are pre-generated and committed, so python isn't needed for rebuilds).

## Install on the router

1. Get API credentials at <https://developer.godaddy.com/keys>
   (**Production** key, not OTE/test).
2. In SRM: **Package Center → Settings → Trust Level → Any publisher**.
3. **Package Center → Manual Install** → upload `dist/godaddy-ddns-<ver>.spk`.
   Don't start it yet (or start it — it just logs a config error until
   configured).
4. SSH to the router (`ssh admin@<router>`, enable SSH first under
   Control Panel → Services), then:

   ```sh
   sudo vi /var/packages/godaddy-ddns/target/etc/godaddy-ddns.conf
   ```

   Set `API_KEY`, `API_SECRET`, `DOMAIN`, and `RECORDS`
   (e.g. `RECORDS="@ www vpn"`).
5. Test once by hand and check the result:

   ```sh
   sudo /var/packages/godaddy-ddns/target/bin/godaddy-ddns.sh --force
   sudo tail /var/packages/godaddy-ddns/target/var/godaddy-ddns.log
   ```

6. Start (or restart) the package in Package Center. Done — it now checks
   every 5 minutes and only calls GoDaddy when your IP actually changes.

## Configuration reference

`/var/packages/godaddy-ddns/target/etc/godaddy-ddns.conf` (root-only, 0600):

| Key | Default | Meaning |
|---|---|---|
| `API_KEY` / `API_SECRET` | — | GoDaddy production API credentials |
| `DOMAIN` | `example.com` | Zone hosted at GoDaddy |
| `RECORDS` | `@` | Space-separated A-record names (`@` = bare domain) |
| `TTL` | `600` | Record TTL in seconds (GoDaddy minimum 600) |
| `CHECK_INTERVAL` | `300` | Seconds between public-IP checks |

Config survives package upgrades (stashed by `preupgrade`, restored by
`postinst`). Uninstalling removes everything.

## Layout

```
INFO.in                      # SPK metadata template (version/checksum filled by build.sh)
build.sh                     # builds dist/godaddy-ddns-<ver>.spk
package/bin/godaddy-ddns.sh  # one-shot updater (the actual logic)
package/bin/godaddy-ddnsd.sh # daemon loop
package/etc/godaddy-ddns.conf.default
scripts/                     # SPK lifecycle scripts (start-stop-status, postinst, ...)
```
