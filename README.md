# Ansible US3LIMS deployment 

This repository is a collection of ansible roles that are used to deploy and keep a us3 lims server up to date. 

Builds are currently all on Centos8

## Current State 
In production

## Getting Started

How to get it setup and working. 

### Prerequisites

If not already installed, [install ansible.]( https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html )

### Get other requirements 

There are a couple of ansible roles used developed by [geerlingguy](https://galaxy.ansible.com/geerlingguy) that we use. 

Run ansible-galaxy on the requirements.yml file to obtain the roles. 

```
ansible-galaxy install -r requirements.yml
```

## Using it

Modifying the example-playbook.yml is a good starting ground. 

### Some required variable definitons: 

`us3_db_pass` - database password for newus3 user

`root_db_pass` - database password for root mysql user 

`gbl_db_pass` - database password for global (gfac) user 
 
`us3php_db_pass` - database password for us3php user 

`limsadmin_db_pass` - database password for limsadmin 

`admin_email` - Email of Admin that will be primarily responsible for the LIMS server 

`admins_db_pass` - Initial DB password for all admins - Defaults are for Alexey, Borries and Gary

`ipaddr_ext` - External/Public facing IP address of the LIMS server 

`ipaddr_int` - The internal IP address of the host
 
`cron_admin` - MAILTO cron admin needs to be defined. 


### Running it: 
```
ansible-playbook foobar-lims.yml
```

#### Encrypting the playbooks 

Since using passwords are neccessary, I would recommend either encrypting the password strings or encrypting the entire playbook. The best way to handle this is likely using [ansible vault.](https://docs.ansible.com/ansible/latest/user_guide/vault.html) I will provide the main example below: 

To do the encryption: 
```
ansible-vault encrypt foobar-lims.yml
```
You'll be prompted for a new Vault password. Standard practices apply for this password. 

Once encryption is done the file will look something like this now: 
```
$ANSIBLE_VAULT;1.1;AES256
35393464386239313434646663656134633933336263336165663063326564376539336431393938
656666323666636432366536656661663...
```

To run the playbook now you can use `--ask-vault` to be prompted for a password. You can view their docs on this for other options. 
```
ansible-playbook foobar-lims.yml --ask-vault
``` 

Oh no! How will you edit this now? 

You can run: 
```
ansible-vault edit foobar-lims.yml
```
This will open the file in plain text in your default editor. 

Alternatively, you can encrypt and decrypt it every time with:
```
ansible-vault decrypt foobar-lims.yml 
```
The last tid bit is you can change the 'Vault Password' by using 
```
ansible-vault rekey foobar-lims.yml
````

An example file was uploaded in the repository with the vault password of `test` :)


## Related Projects

[Ultrascan3](https://github.com/ehb54/ultrascan3)
