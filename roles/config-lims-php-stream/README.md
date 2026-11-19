# Ansible LIMS role: choose the php module stream

On EL8, enables the `php:7.4` module stream (`lims_php_stream`) when no php stream is enabled yet, so a new host does not get the retired default `php:7.2`. It is a dependency of `config-lims-packages`, `config-lims-us3-user` and `config-lims-php`, the roles that install php.

A host already on another stream is only reported. To move it, run `upgrade-php-playbook.yml`, which also rebuilds the hand-built PECL extensions (role `upgrade-lims-php`).

On EL10, which has no dnf module streams, the php version comes with the package names: `php-*` is php 8.3, the version the LIMS roles install, and `php8.4-*` is php 8.4. The two conflict, so the role stops on a host that already has `php8.4-common`, before any role changes it.

Does nothing on other platforms.

## Role Variables

`lims_php_stream` - php module stream to enable, default `"7.4"`

`tasks/read.yml` sets `lims_php_stream_enabled` to the enabled stream, or `''`; `upgrade-lims-php` uses it.
