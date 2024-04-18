#!/bin/bash

# Load environment variables
if [ -f ".env" ]; then
    source .env
else
    echo "Error: .env file not found."
    exit 1
fi

# Set directory based on the stage, defaulting to staging
if [[ "$ENVIRONMENT_STAGE" == "production" ]]; then
    DIR="inventory/production"
else
    DIR="inventory/staging"
fi

# Ensure directories exist
mkdir -p $DIR/host_vars
mkdir -p $DIR

# Create host_vars file
cat > $DIR/host_vars/$TARGET_HOSTNAME.yml <<EOF
---
ansible_host: "${TARGET_ANSIBLE_HOST:-}"
ansible_distribution: "${TARGET_ANSIBLE_DISTRIBUTION:-'Ubuntu'}"
hostname: "${TARGET_HOSTNAME:-'default-hostname'}"
ansible_user: "${TARGET_ANSIBLEUSER:-'ansible'}"
ansible_pass: "${TARGET_ANSIBLEPASS:-'password'}"
ansible_ssh_private_key_file: "${TARGET_ANSIBLEUSER_SSH_PRIVATE_KEY_FILE:-''}"
ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
adminuser: "${TARGET_ADMINUSER:-'admin'}"
adminpwd: "${TARGET_ADMINPASS:-'password'}"
EOF

# Create or update hosts.ini
cat > $DIR/hosts.ini <<EOF
[all]
$TARGET_HOSTNAME ansible_host=${TARGET_ANSIBLE_HOST:-'localhost'}

[staging]
$TARGET_HOSTNAME

[production]
$TARGET_HOSTNAME
EOF

# Encrypt the host_vars file using Ansible Vault
if [ ! -z "$ANSIBLE_VAULT_PASSWORD" ]; then
    echo "$ANSIBLE_VAULT_PASSWORD" > .vault_pass.txt
    ansible-vault encrypt $DIR/host_vars/$TARGET_HOSTNAME.yml --vault-password-file .vault_pass.txt
    echo "Encrypted host vars for $TARGET_HOSTNAME using Ansible Vault."
    chmod 600 .vault_pass.txt
    echo "chmod 600 .vault_pass.txt done."
    # Set up or modify ansible.cfg to use the vault password file
    cat > ansible.cfg <<EOF
[defaults]
inventory = ./inventory/
vault_password_file = ./.vault_pass.txt
EOF
    echo "Updated ansible.cfg with vault password file."
else
    echo "Vault password not set. Skipping encryption."
fi

echo "Inventory for $TARGET_HOSTNAME has been set up in $DIR."
