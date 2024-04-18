#!/bin/bash
echo ""
echo "______   ___   _____  _____  _   _ ___  ___  ___   _____  _   _  _____ ______ "
echo "| ___ \ / _ \ /  ___||  ___|| \ | ||  \/  | / _ \ |  ___|| | | ||  ___|| ___ \ "
echo "| |_/ // /_\ \\ \`--. | |__  |  \| || .  . |/ /_\ \| |__  | |_| || |__  | |_/ /"
echo "|    / |  _  | \`--. \|  __| | . \` || |\/| ||  _  ||  __| |  _  ||  __| |    / "
echo "| |\ \ | | | |/\__/ /| |___ | |\  || |  | || | | || |___ | | | || |___ | |\ \ "
echo "\_|_\_|\_| |_/\____/ \____/ \_|_\_/\_|  |_/\_|_|_/\____/ \_| |_/\____/ \_| \_|"
echo " / _ \ | \ | |/  ___||_   _|| ___ \| |    |  ___|                             "
echo "/ /_\ \|  \| |\ \`--.   | |  | |_/ /| |    | |__                               "
echo "|  _  || . \` | \`--. \  | |  | ___ \| |    |  __|                              "
echo "| | | || |\  |/\__/ / _| |_ | |_/ /| |____| |___                              "
echo "\_| |_/\_| \_/\____/  \___/ \____/ \_____/\____/                              "
echo "                                                                              "
echo "                                                                             "
echo "Version: 18 April 2024" 
echo "" 


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

# Create or update hosts.ini in the main inventory directory
cat > inventory/hosts.ini <<EOF
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
    chmod 600 .vault_pass.txt
    # Define a vault ID for clarity and consistency
    VAULT_ID="default"
    # Encrypt with specified vault ID
    ansible-vault encrypt $DIR/host_vars/$TARGET_HOSTNAME.yml --vault-password-file .vault_pass.txt --encrypt-vault-id $VAULT_ID
    if [ $? -eq 0 ]; then
        echo "Encrypted host vars for $TARGET_HOSTNAME using Ansible Vault with vault-id $VAULT_ID."
    else
        echo "Failed to encrypt the host vars. Check the vault setup."
        exit 1
    fi
    # Set up or modify ansible.cfg to use the vault password file
    cat > ansible.cfg <<EOF
[defaults]
inventory = ./inventory/hosts.ini
vault_password_file = ./.vault_pass.txt
host_key_checking = False
EOF
    echo "Updated ansible.cfg with vault password file."
else
    echo "Vault password not set. Skipping encryption."
fi

echo "Inventory for $TARGET_HOSTNAME has been set up in $DIR."
echo ""
echo ""
