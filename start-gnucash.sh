#!/bin/bash
set -ex

export DEBIAN_FRONTEND=noninteractive
export DISPLAY=:0

BUILD_DIR=/app/build
INSTALL_PREFIX=/app/install

# Build GnuCash if not already built
if [ ! -f "$BUILD_DIR/build.ninja" ]; then
    echo "=== Configuring GnuCash ==="
    cmake -B "$BUILD_DIR" -G Ninja \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
        -DCMAKE_BUILD_TYPE=Release \
        -DWITH_AQBANKING=OFF \
        -DWITH_PYTHON=OFF \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_C_FLAGS="-Wno-error" \
        -DCMAKE_CXX_FLAGS="-Wno-error" \
        /app

    echo "=== Building GnuCash (this may take 20-30 minutes on first run) ==="
    ninja -C "$BUILD_DIR" -j"$(nproc)"

    echo "=== Installing GnuCash ==="
    ninja -C "$BUILD_DIR" install

    # Compile GSettings schemas
    glib-compile-schemas "$INSTALL_PREFIX/share/glib-2.0/schemas/"
fi

# Set up runtime environment
export LD_LIBRARY_PATH="$INSTALL_PREFIX/lib:$INSTALL_PREFIX/lib/gnucash:${LD_LIBRARY_PATH:-}"
export GSETTINGS_SCHEMA_DIR="$INSTALL_PREFIX/share/glib-2.0/schemas"
export XDG_DATA_DIRS="$INSTALL_PREFIX/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

# Start D-Bus session (needed for dconf/GSettings)
eval "$(dbus-launch --sh-syntax)"
export DBUS_SESSION_BUS_ADDRESS

# Start virtual framebuffer
Xvfb :0 -screen 0 1280x800x24 -ac 2>/dev/null &
sleep 2

# Start window manager
openbox --config-file /etc/openbox/minimal-rc.xml 2>/dev/null &
sleep 1

# Start VNC server (no password for simplicity in dev preview)
x11vnc -display :0 -forever -shared -nopw -rfbport 5900 -xkb -noxdamage -bg
sleep 1

# Start noVNC/websockify on port 3000
websockify --web=/opt/novnc 0.0.0.0:3000 localhost:5900 &
sleep 2

# Start GnuCash
echo "=== Starting GnuCash ==="
"$INSTALL_PREFIX/bin/gnucash" &

# Keep container alive
wait
