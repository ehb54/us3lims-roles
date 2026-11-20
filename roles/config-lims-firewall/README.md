# Ansible LIMS role: configure the firewall

A role to configure the firewall for a LIMS server. 
The following services are enabled: 
- https
- http 
- ssh 
- mysql 

It also opens UDP `udpport` (12233), where us3-listen receives job status messages (not under `NO_LIMS`).

## Requirements 
None
## Role Variables 
`udpport` (config-lims-lims, default 12233)
## Example Playbook 
```yaml
- hosts: servers  
  roles:
    - config-lims-firewall
