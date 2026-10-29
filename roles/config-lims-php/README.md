# Ansible LIMS role: configure php


A role to configure the php service for a LIMS server. 
This also installs the imagick_module (PECL imagick `lims_php_imagick_version`), rebuilding it when the installed one does not load, e.g. after a php upgrade. Its dependency `config-lims-php-stream` picks the php module stream on EL8.

## Requirements 

None

## Role Variables 

none 

## Example Playbook 
```yaml
- hosts: servers  
  roles:
    - config-lims-php
