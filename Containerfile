# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM ghcr.io/ublue-os/bazzite-deck-gnome:stable

## Other possible base images include:
# FROM ghcr.io/ublue-os/bazzite:latest
# FROM ghcr.io/ublue-os/bluefin-nvidia:stable
# 
# ... and so on, here are more base images
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base image: quay.io/fedora/fedora-bootc:41
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10

### [IM]MUTABLE /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# RUN rm /opt && mkdir /opt

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

# Setup Copr repos
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    dnf5 -y copr enable ublue-os/staging && \
    dnf5 -y copr enable ublue-os/packages && \
    dnf5 -y copr enable ublue-os/bazzite && \
    dnf5 -y copr enable ublue-os/bazzite-multilib && \
    dnf5 -y copr enable ublue-os/obs-vkcapture && \
    dnf5 -y copr enable ublue-os/hhd && \
    dnf5 -y copr enable ycollet/audinux && \
    dnf5 config-manager unsetopt skip_if_unavailable && \
    /ctx/cleanup

# Install new packages
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    dnf5 -y install \
        jupiter-fan-control \
        jupiter-hw-support-btrfs \
        galileo-mura \
        steamdeck-dsp \
        powerbuttond \
        $([[ "$IMAGE_BRANCH" == "unstable" || "$IMAGE_BRANCH" == "testing" ]] && echo "hhd-git" || echo "hhd") \
        hhd-ui \
        steamos-manager \
        acpica-tools \
        vpower \
        steam_notif_daemon \
        sdgyrodsu \
        ibus-pinyin \
        ibus-table-chinese-cangjie \
        ibus-table-chinese-quick \
        socat \
        zstd \
        zenity \
        newt \
        qt6-qtvirtualkeyboard \
        xorg-x11-server-Xvfb \
        python-vdf \
        python-crcmod && \
    git clone https://github.com/bazzite-org/jupiter-dock-updater-bin.git \
        --depth 1 \
        /tmp/jupiter-dock-updater-bin && \
    mv -v /tmp/jupiter-dock-updater-bin/packaged/usr/lib/jupiter-dock-updater /usr/libexec/jupiter-dock-updater && \
    setfattr -n user.component -v "jupiter-dock-updater" /usr/libexec/jupiter-dock-updater/* && \
    ln -s /usr/bin/steamos-logger /usr/bin/steamos-info && \
    ln -s /usr/bin/steamos-logger /usr/bin/steamos-notice && \
    ln -s /usr/bin/steamos-logger /usr/bin/steamos-warning && \
    /ctx/cleanup

# Install Steam Deck patched UPower
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    dnf5 -y swap \
    --repo copr:copr.fedorainfracloud.org:ublue-os:bazzite \
        upower upower && \
    dnf5 versionlock add \
        upower \
        upower-libs && \
    /ctx/cleanup

# Install Gamescope Session & Supporting changes
# Add bootstrap_steam.tar.gz used by gamescope-session (Thanks GE & Nobara Project!)
# Add sdl gamecontrollerdb used by handheld daemon for externals
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=GITHUB_TOKEN \
    mkdir -p /usr/share/gamescope-session-plus/ && \
    curl --retry 3 -Lo /usr/share/gamescope-session-plus/bootstrap_steam.tar.gz https://large-package-sources.nobaraproject.org/bootstrap_steam.tar.gz && \
    setfattr -n user.component -v "bootstrap_steam" /usr/share/gamescope-session-plus/bootstrap_steam.tar.gz && \
    mkdir -p /usr/share/sdl/ && \
    /ctx/ghcurl "https://raw.githubusercontent.com/mdqinc/SDL_GameControllerDB/refs/heads/master/gamecontrollerdb.txt" -Lo /usr/share/sdl/gamecontrollerdb.txt && \
    setfattr -n user.component -v "sdl2" /usr/share/sdl/gamecontrollerdb.txt && \
    dnf5 -y install \
    --repo copr:copr.fedorainfracloud.org:ublue-os:bazzite \
        gamescope-session-plus \
        gamescope-session-steam && \
    /ctx/cleanup

# Cleanup & Finalize
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    mkdir -p "/etc/xdg/autostart" && \
    mv "/etc/skel/.config/autostart/steam.desktop" "/etc/xdg/autostart/steam.desktop" && \
    sed -i 's@Exec=waydroid first-launch@Exec=/usr/bin/waydroid-launcher first-launch\nX-Steam-Library-Capsule=/usr/share/applications/Waydroid/capsule.png\nX-Steam-Library-Hero=/usr/share/applications/Waydroid/hero.png\nX-Steam-Library-Logo=/usr/share/applications/Waydroid/logo.png\nX-Steam-Library-StoreCapsule=/usr/share/applications/Waydroid/store-logo.png\nX-Steam-Controller-Template=Desktop@g' /usr/share/applications/Waydroid.desktop && \
    if grep -q "kinoite" <<< "${BASE_IMAGE_NAME}"; then \
        sed -i 's/Exec=.*/Exec=systemctl start return-to-gamemode.service/' /etc/skel/Desktop/Return.desktop \
    ; fi && \
    sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nNoDisplay=true@g' /usr/share/applications/input-remapper-gtk.desktop && \
    for copr in \
        ublue-os/staging \
        ublue-os/packages \
        ublue-os/bazzite \
        ublue-os/bazzite-multilib \
        ublue-os/obs-vkcapture \
        ublue-os/hhd \
        ycollet/audinux; \
    do \
        dnf5 -y copr disable -y $copr; \
    done && unset -v copr && \
    if grep -q "silverblue" <<< "${BASE_IMAGE_NAME}"; then \
        systemctl disable gdm.service && \
        systemctl enable sddm.service \
    ; else \
        systemctl disable usr-share-sddm-themes.mount \
    ; fi && \
    { rm -v /usr/share/applications/bazzite-steam-bpm.desktop || true; } && \
    systemctl enable hhd.service && \
    systemctl enable --global steamos-manager.service && \
    systemctl enable bazzite-autologin.service && \
    systemctl enable wireplumber-workaround.service && \
    systemctl enable wireplumber-sysconf.service && \
    systemctl enable pipewire-workaround.service && \
    systemctl enable pipewire-sysconf.service && \
    systemctl enable cec-onboot.service && \
    systemctl enable cec-onpoweroff.service && \
    systemctl enable cec-onsleep.service && \
    systemctl enable bazzite-tdpfix.service && \
    systemctl --global disable sdgyrodsu.service && \
    systemctl disable input-remapper.service && \
    systemctl disable uupd.timer && \
    systemctl disable jupiter-fan-control.service && \
    systemctl disable vpower.service && \
    systemctl disable jupiter-biosupdate.service && \
    systemctl disable jupiter-controller-update.service && \
    dnf5 config-manager setopt skip_if_unavailable=1 && \
    /ctx/image-info && \
    /ctx/build-initramfs && \
    /ctx/finalize
    
### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
