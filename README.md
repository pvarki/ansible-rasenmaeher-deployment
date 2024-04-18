# ansible-rasenmaeher-deployment
Ansible playbook to deploy Rasenmaeher to a (local) virtual machine.

# How to Run
Define your variables: addresses and secrets, to an .env. Template provided. Run set-inventory.sh to create a hostfile.yml according what you want to build. 

1. Define variables to your .env.
2. $ bash set-inventory.sh - create a staging host to /inventory/staging & load up .env
3. Run ansible-playbook site.yml -vv - to deploy & manage your Miniwerk Rasenmaeher inventory.

# Logic
### /inventory/group_vars
- Group 'local'
Vars for local things
- Group 'miniwerk'
Vars required by managing Miniwerk Rasenmaeher deployment
- Group 'all'
Global vars
### /inventory/production
Define each production environment that you manage, in this folder with file like "server1.yml", template provided. This repo has .gitignore to NOT include any production environments to git. Consider encrypting with Ansible Vault as well.
### /inventory/staging
Similarily, define any staging environment here.
### /playbooks/
Site.yml resides here, as well partial plays. Edit site.yml for your local use in will.
### /roles/
- Role 'prepare-vm': Run some preparations in your target vm. TODO: Replace with our Ansible Galaxy role
- Role 'docker': Included in prepare-vm play. Install docker, compose as prequisitions.
- Role 'install-rm': Included in manage-rm play. Run docker compose in the target.

# To-do
- Move prepare-vm roles ansible galaxy?
- Include ProxmoxVE VM deploying roles from Ansible Galaxy (get them to there first from arti1 ansible)