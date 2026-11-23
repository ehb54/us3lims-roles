# Ansible role: per-user VNC desktops on EL10

The EL10 counterpart of `install-vncserver`. Each registered user gets their own Xvnc desktop on a loopback port, started with `sudo vncctl start` and reached through an SSH tunnel, as on EL8. ultrascan-tickets#1292.

## Why

EL10 ships no X.Org server and no Xvnc (`tigervnc-server`), no xrdp, and no X11 desktop: GNOME 49 is Wayland-only, and Xfce and MATE aren't in EPEL 10. That holds for OL10 BaseOS, AppStream, CRB, Oracle EPEL and Fedora EPEL 10. So `install-vncserver` and `install-xrdp` can't be installed there.

The TigerVNC project publishes its own EL10 RPMs. Their Xvnc is built from a bundled xorg-server, so it doesn't need EL10's missing X server. The rest of the stack is in the distribution repos:

- `xorg-x11-xinit` and `icewm` come from EPEL 10;
- `xorg-x11-xauth`, `dbus-x11`, `mesa-dri-drivers` and `xkbcomp` come from AppStream.

The desktop inside each session is icewm.

## What it does

1. Stops unless the host is EL10 or later.
2. Downloads the TigerVNC RPMs (`tigervnc_el10_rpms`) into `tigervnc_el10_rpm_dir`, each checked against its pinned SHA-256. A file that is already there and matches isn't fetched again. Each file gets `tigervnc_el10_download_timeout` seconds per attempt and `tigervnc_el10_download_retries` more attempts.
3. Installs them in one dnf transaction with `vnc_el10_packages` (icewm, xterm, Type1 fonts, firefox).
   - `tigervnc-server` requires `tigervnc-selinux` whenever `selinux-policy-targeted` is installed, so the whole set goes in together.
   - GPG checking is off for these local files only. The RPMs are signed, but EL10's rpm refuses to import TigerVNC's key (fingerprint `95EF2D885E44FE1788C59D3E327F91294582A460`): its self-signature uses SHA-1. The checksums stand in for the signature check.
4. Installs `vncadmin`, `vncctl`, the `vncusers` group and the sudoers rule, as `install-vncserver` does. `vncadmin` writes `session={{ vnc_session }}` into new users' `~/.vnc/config` instead of `session=gnome`.
5. Writes `/etc/icewm/toolbar` when `qt_version` and `qwt_version` are set. Its buttons follow the EL8 GNOME favorites (config-lims-gui): UltraScan, US-GMP (`us_comproject`, only with `install_commercial`), US-SOMO, Firefox and a terminal. The file replaces icewm's own toolbar.
6. On a fresh install, runs `vncadmin add` for `vnc_admin_users`. It writes the provisioned marker with the same logic as `install-vncserver`; see Notes.

Users and admins work as on EL8:

```
sudo vncadmin add <user>       # admin: registers the user, assigns display :N (port 5900+N)
vncpasswd                      # user: sets the VNC password
sudo vncctl start              # user: starts vncserver@:N; prints the port for the SSH tunnel
```

Xvnc listens on 127.0.0.1 and ::1 only (`localhost` in `~/.vnc/config`), so the role opens no firewall port. Viewers connect through `ssh -L 590N:localhost:590N user@host`. By default Xvnc also offers TLS (VeNCrypt TLSVnc) inside the tunnel.

## Role Variables

See `defaults/main.yml`.

`tigervnc_el10_version`, `tigervnc_el10_release` - the TigerVNC build to install, default `1.16.2`, `1.el10`

`tigervnc_el10_url` - base URL of the project's EL10 RPMs (SourceForge)

`tigervnc_el10_rpms` - name, arch and SHA-256 of each RPM. Change it together with the version.

`tigervnc_el10_rpm_dir` - where the RPMs are kept, default `/var/cache/tigervnc-el10`

`tigervnc_el10_download_timeout` - seconds per download attempt, default 60 (get_url's own default is 10)

`tigervnc_el10_download_retries` - further attempts per file after a failed one, 10 s apart, default 5

`vnc_el10_packages` - distribution packages installed with them, default icewm, xterm, xorg-x11-fonts-Type1, firefox. A fresh install gets firefox with the Workstation group too, but Leapp's EL9 to EL10 upgrade removes it.

`vnc_session`, `vnc_geometry` - what `vncadmin` writes into a new user's `~/.vnc/config`, default `icewm-session`, `1920x1200`

`vnc_admin_users` - accounts registered on a fresh install (created by config-lims-admin)

`vnc_icewm_toolbar` - write `/etc/icewm/toolbar`, default `true`

## Notes

- **Updates:** the RPMs don't come from a repo, so `dnf update` never touches them. To update:
  1. Set `tigervnc_el10_version` and the six checksums to a newer TigerVNC release.
  2. Re-run the role.
  3. Users' running sessions keep the old Xvnc until `sudo vncctl restart`.
- **EPEL:** icewm and `xorg-x11-xinit` need EPEL 10 enabled (the install play's pre_tasks enable it).
- **After an in-place OS upgrade** (`lims_os_upgrade`): the old OS's tigervnc-server goes on the way to EL10, and RPM keeps its `vncserver.users` as `vncserver.users.rpmsave`. The role puts the display assignments from it back when the new `vncserver.users` has none.
- **Admin markers:** config-lims-admin writes `/etc/lims-admin-accounts-pending`, and whichever VNC role runs last writes `/etc/lims-admin-accounts-provisioned`. On EL10 that is this role. A play that runs neither VNC role must write the marker some other way, or every later run counts as a fresh install.
- **`~/.vnc`:** TigerVNC 1.16 logs that `~/.vnc` is deprecated (new paths are `~/.config/tigervnc` and `~/.local/state/tigervnc`), but it still reads `~/.vnc/config` and `~/.vnc/passwd`. `vncadmin` and `vncctl` keep using `~/.vnc`, as on EL8.
- **Users with an EL8 `~/.vnc/config`:** a `session=gnome` line still gives them a desktop.
  - EL10 has no `/usr/share/xsessions/gnome.desktop`, so TigerVNC logs "Could not load configured desktop session gnome".
  - It then starts the first session file in `/usr/share/xsessions`, which on these hosts is `icewm-session`.
  - Changing the line to `session=icewm-session` only removes the warning.
  - `vncadmin info` shows such a file as "Custom".
  - GNOME itself can't run inside Xvnc on EL10: gnome-shell 49's X11 mode crashes at startup.
