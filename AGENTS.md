# GnuCash — Base44 Dev Environment

## What this is
GnuCash is a C/C++ GTK3 **desktop** accounting application, not a web app.
The Base44 preview shows web content on port 3000, so the desktop GUI is
served via **noVNC** (a web-based VNC client) through a virtual framebuffer.

## Architecture
- **Dockerfile.base44** — Ubuntu 24.04 image with all build deps + display
  infrastructure (Xvfb, openbox, x11vnc, noVNC, websockify).
- **start-gnucash.sh** — Runs at container startup:
  1. Builds GnuCash from source with CMake + Ninja (cached in named volumes).
  2. Installs to `/app/install`.
  3. Starts Xvfb (virtual display :0, 1280×800).
  4. Starts openbox (window manager).
  5. Starts x11vnc (VNC server on port 5900, no password).
  6. Starts websockify/noVNC on port 3000 (web client + WebSocket proxy).
  7. Launches `gnucash` in the virtual display.
- **docker-compose.base44.yml** — Bind-mounts source at `/app`, named volumes
  for `/app/build` and `/app/install`, maps port 3000.

## Build configuration
- CMake flags: `-DWITH_AQBANKING=OFF -DWITH_PYTHON=OFF -DCMAKE_BUILD_TYPE=Release`
- `-Wno-error` added to C/C++ flags (GCC 13 in Ubuntu 24.04 produces new warnings)
- Aqbanking disabled (requires `gwengui-gtk3` which is hard to find on Ubuntu)
- 854 build targets; first build takes ~5 minutes, subsequent restarts are instant
  (build artifacts cached in `gnucash-build` and `gnucash-install` volumes)

## No external secrets needed
GnuCash is a local desktop app. No external API keys or credentials required.

## Verifying it works
- `curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/` → 200
- Open the preview tab → noVNC auto-connects → GnuCash desktop appears
- `docker compose -f docker-compose.base44.yml logs --tail 20` to check status

## Editing code
- Source is bind-mounted; edits are reflected in the repo immediately.
- After editing C/C++ code, rebuild: `docker compose exec gnucash ninja -C /app/build && docker compose exec gnucash ninja -C /app/build install`
- Then restart GnuCash: `docker compose restart gnucash`
- Call `reload_preview` after restarting to refresh the noVNC view.
