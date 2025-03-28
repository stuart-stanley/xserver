FROM balenalib/raspberrypi5-ubuntu:noble


RUN install_packages \
    matchbox-window-manager \
    matchbox-keyboard \
    x11-xserver-utils \
    x11-utils \
    xauth \
    xfonts-base xfonts-100dpi xfonts-75dpi fonts-unifont \
    xinit \
    xinput \
    xserver-xorg \
    xserver-xorg-input-all \
    xserver-xorg-input-evdev \
    xserver-xorg-legacy \
    xserver-xorg-video-all

WORKDIR /opt/xserver

COPY src/xinitrc /root/.xinitrc

COPY src/entry.sh src/config.sh VERSION /opt/xserver/
COPY src/99-vc4.conf /etc/X11/xorg.conf.d/99-vc4.conf
RUN chmod +x /opt/xserver/*.sh

# use the balena entry.sh to run our x11 spinup shell
ENTRYPOINT  ["/bin/bash", "/bin/entry.sh", "/opt/xserver/entry.sh"]

ENV CURSOR=true \
    UDEV=on \
    FORCE_DISPLAY=:0
