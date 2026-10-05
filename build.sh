#!/usr/bin/env bash
# Builds VLC-<version>-x86_64.AppImage from Debian's VLC packages inside a
# Debian container.
#
# Usage: ./build.sh [vlc-version] [debian-suite]
#   ./build.sh                    # 3.0.23 from bookworm
#   ./build.sh 3.0.23 trixie
#
# Env: DOCKER_DNS  DNS server for the container (e.g. 8.8.8.8), optional
set -euo pipefail
cd "$(dirname "$0")"

VLC_VERSION="${1:-3.0.23}"
DEBIAN_SUITE="${2:-bookworm}"

docker_args=(--rm -i -v "$PWD":/work -w /work
  -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)"
  -e VLC_VERSION="$VLC_VERSION" -e DEBIAN_SUITE="$DEBIAN_SUITE")
if [[ -n "${DOCKER_DNS:-}" ]]; then
  docker_args+=(--dns "$DOCKER_DNS")
fi

docker run "${docker_args[@]}" "debian:${DEBIAN_SUITE}-slim" bash -euo pipefail <<'EOF'
trap 'chown -R "$HOST_UID:$HOST_GID" /work' EXIT
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# Map the upstream version to the Debian package version in this suite
DEB_VERSION=$(apt-cache madison vlc | awk -v v="$VLC_VERSION-" '{ if (index($3, v) == 1) { print $3; exit } }')
if [[ -z "$DEB_VERSION" ]]; then
  echo "VLC $VLC_VERSION is not available in Debian $DEBIAN_SUITE. Available:" >&2
  apt-cache madison vlc >&2
  exit 1
fi
export VLC_VERSION DEBIAN_SUITE DEB_VERSION
export DEBIAN_MAJOR=$(cut -d. -f1 /etc/debian_version)
echo "Building VLC $VLC_VERSION from Debian $DEBIAN_SUITE ($DEBIAN_MAJOR) package $DEB_VERSION"

apt-get install -y -qq --no-install-recommends \
  python3-venv python3-pip ca-certificates wget file patchelf squashfs-tools \
  desktop-file-utils libglib2.0-bin fakeroot gtk-update-icon-cache gnupg zsync binutils >/dev/null
python3 -m venv /opt/abv
/opt/abv/bin/pip install -q appimage-builder
/opt/abv/bin/appimage-builder --recipe AppImageBuilder.yml --skip-tests
EOF
