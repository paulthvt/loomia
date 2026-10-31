#!/bin/sh
# Renders every app icon from the Loomia mark (Figma `07 — Loomia logo`, E5b).
# Needs rsvg-convert (`brew install librsvg`). Run from the repo root after
# changing the geometry below; commit the PNGs it writes. The same geometry is
# in lib/core/ui/loomia_mark.dart and in paulthvt/loomia-site
# (src/components/Mark.astro, public/favicon.svg): change them together.
set -eu

BRAND='#E8964A'

# The mark in its own units (100px type): ring r 28.5 / 15.5, three dots.
# Centred on its bounding box and scaled to 56% of the canvas height.
mark() { # $1 = fill, $2 = centre x, $3 = centre y, $4 = scale (1024px canvas)
  cat <<SVG
<g transform="translate(${2:-512} ${3:-512}) scale(${4:-7.7096}) translate(5.1847 8.6905)" fill="$1">
  <circle r="22" fill="none" stroke="$1" stroke-width="13"/>
  <circle cx="-35.119" cy="-16.376" r="3.75"/>
  <circle cx="-18.046" cy="-35.418" r="4.75"/>
  <circle cx="7.076" cy="-40.131" r="5.75"/>
</g>
SVG
}

# $1 = corner radius of the tile (0 = full bleed, for masked platforms)
icon() {
  cat <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024">
  <rect width="1024" height="1024" rx="$1" fill="$BRAND"/>
  $(mark white)
</svg>
SVG
}

tmp=$(mktemp -d)
icon 0 > "$tmp/square.svg"
icon 229 > "$tmp/tile.svg"   # 22.37%, the Figma icon radius

png() { # $1 = svg, $2 = size, $3 = output
  rsvg-convert -w "$2" -h "$2" "$tmp/$1.svg" -o "$3"
}

# iOS masks the icon itself and rejects alpha: full bleed, no transparency.
ios=ios/Runner/Assets.xcassets/AppIcon.appiconset
png square 1024 "$tmp/ios.png"
magick "$tmp/ios.png" -background "$BRAND" -alpha remove -alpha off -strip \
  "$ios/Icon-App-1024x1024@1x.png"

# Web: rounded tile where the browser shows it as is, full bleed where it masks.
png tile 32 web/favicon.png
png tile 192 web/icons/Icon-192.png
png tile 512 web/icons/Icon-512.png
png square 192 web/icons/Icon-maskable-192.png
png square 512 web/icons/Icon-maskable-512.png
png square 180 web/icons/apple-touch-icon.png

# Android below 8.0; 8.0+ uses the adaptive vector in mipmap-anydpi-v26.
res=android/app/src/main/res
png tile 48 $res/mipmap-mdpi/ic_launcher.png
png tile 72 $res/mipmap-hdpi/ic_launcher.png
png tile 96 $res/mipmap-xhdpi/ic_launcher.png
png tile 144 $res/mipmap-xxhdpi/ic_launcher.png
png tile 192 $res/mipmap-xxxhdpi/ic_launcher.png

# Launch screens: the ring alone, 96pt across (LaunchSplash.ring). Android and
# web draw it as a vector: drawable/launch_ring.xml, web/index.html.
cat > "$tmp/ring.svg" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96">
  <circle cx="48" cy="48" r="37.0525" fill="none" stroke="white" stroke-width="21.895"/>
</svg>
SVG
launch=ios/Runner/Assets.xcassets/LaunchImage.imageset
png ring 96 $launch/LaunchImage.png
png ring 192 $launch/LaunchImage@2x.png
png ring 288 $launch/LaunchImage@3x.png

# Play Store listing, uploaded by hand: the icon full bleed (Play masks it) and
# the 1024x500 feature graphic, the mark at the same 56% of the height. Play
# rejects alpha on the feature graphic.
store=store/play
mkdir -p $store
png square 512 $store/icon-512.png
cat > "$tmp/feature.svg" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="500">
  <rect width="1024" height="500" fill="$BRAND"/>
  $(mark white 512 250 3.7645)
</svg>
SVG
rsvg-convert "$tmp/feature.svg" | magick - -background "$BRAND" -alpha remove \
  -alpha off -strip PNG24:$store/feature-graphic.png

rm -r "$tmp"
