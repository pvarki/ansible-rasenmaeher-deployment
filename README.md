# ansible-rasenmaeher-deployment
Ansible playbook to deploy Rasenmaeher via Miniwerk to a virtual machine.

Target: This playbook lets you create and manage RM instances under ProxmoxVE at will.

# How to Run
Define your variables: addresses and secrets, to an .env. Template provided. Run set-inventory.sh to create a hostfile.yml according what you want to build.

1. Define variables to your .env. Copy-paste the template provided.
2. $ bash set-inventory.sh - create a staging host to /inventory/staging & load up .env
3. Run ansible-playbook site.yml -vv - to deploy & manage your Miniwerk Rasenmaeher inventory.

# Manage Your RM Deplyoment
1. ```ansible-playbook manage_rm.yml -vv -e "add_admin=true"``` to add single-use admincode to RM.
2. ```ansible-playbook manage_rm.yml -vv -e "remove_composition=true"``` to nuke containers, images and volumes to start from scratch.
3. ```ansible-playbook manage_rm.yml -vv -e "pull_new=true"``` to grab new images (TODO).


# Useful Commands
```
ansible-vault decrypt inventory//host_vars/which-host-you-want-to-decrypt.yml --vault-password-file ./vault_pass.txt
```
Decrypt a host yml to see address, credentials etc.

# Env
Template-env provided. Some options:
- RM CI vars? While others have defaults, you **must** define DOCKER_REP_TAG. See Version Tags from https://github.com/pvarki/docker-rasenmaeher-integration for applicable versiontags.
- Use DNS service? If you have a DNS to resolve docker container domainnames for inbound connections, set the flag ```DO_YOU_WANT_TO_USE_DNS``` true.
- Use dy.fi DDNS? If you need to deploy a VM to some local server that needs DDNS, you can use this role. It requires username and pass to dy.fi DDNS service.

# Logic
### source root
The env template & set-inventory.sh to get you going. Unless you are developing things, you don't need to worry much about anything else but this and your inventory.
### /inventory/production
Define each production environment that you manage, in this folder with file like "server1.yml", template provided. This repo has .gitignore to NOT include any production environments to git. Consider encrypting with Ansible Vault as well.
### /inventory/staging
Similarily, any staging environment gets defined here.
### /inventory/group_vars
- Group 'local'
Vars for local things
- Group 'miniwerk'
Vars required by managing Miniwerk Rasenmaeher deployment
- Group 'all'
Global vars
### /playbooks/
Site.yml resides here, as well partial plays. Edit site.yml for your local use in will.
### /roles/
- Role 'prepare-vm': Run some preparations in your target vm. TODO: Replace with our Ansible Galaxy role
- Role 'docker': Included in prepare-vm play. Install docker, compose as prequisitions.
- Role 'install-rm': Included in manage-rm play. Run docker compose in the target.

# To-do
- Move prepare-vm roles ansible galaxy?
- Include ProxmoxVE VM deploying roles from Ansible Galaxy (get them to there first from arti1 ansible)
