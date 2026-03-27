#!/usr/bin/env bash

sudo pacman -S --needed \
  nss nspr at-spi2-core libcups libdrm dbus libxcb libxkbcommon \
  libx11 libxcomposite libxdamage libxext libxfixes libxrandr \
  mesa pango cairo alsa-lib gtk3 libnotify libsecret libglvnd \
  xorg-server-xvfb webkit2gtk libwebp libvpx flite icu libxml2

sudo pacman -S --needed webkit2gtk libsecret

sudo pacman -S chromium firefox

sudo pacman -S --needed icu libxml2 flite libwebp libvpx

sudo mkdir -p /opt/google/chrome
sudo ln -s /usr/bin/chromium /opt/google/chrome/chrome
