#!/bin/bash

echo ""
echo "             __ "
echo "             \ \ "
echo "              \ \ "
echo "               \ \ "
echo "                \/\ "
echo "                |   \   _+,_ "
echo "                 \   (_[____]_ "
echo "                  \._|.-._.-._] ///////////////////// "
echo " ^^^^^^Serving^^^^^^^^'-' '-'^Those^Close^To^Grass^^^ "
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

echo "Installing ansible-galaxy roles..."
ansible-galaxy install -r requirements.yml
echo "Required roles installed."

# Load environment variables
if [ -f ".env" ]; then
    source .env
else
    echo "Error: .env file not found."
    exit 1
fi
echo "Env vars loaded."

# Set directory based on the stage, defaulting to staging
INV_DIR="inventory"
HOST_VARS_DIR="$INV_DIR/host_vars"
TARGET_HOST_VARS_DIR="$INV_DIR/host_vars/$TARGET_HOSTNAME"
GROUP_VARS_DIR="$INV_DIR/group_vars/${ENVIRONMENT_STAGE:-staging}"

# Ensure directories exist
mkdir -p "$HOST_VARS_DIR" "$GROUP_VARS_DIR" "$TARGET_HOST_VARS_DIR"

# Define the deployment source and Docker Compose project path for local deployment
DEPLOYMENT_SOURCE="${DEPLOYMENT_SOURCE:-local}"  # default to local if not set
DOCKER_COMPOSE_PATH="${PWD}/docker-rasenmaeher-integration"  # Adjust the path as necessary

# Write environment variables to a host_vars file
cat > "$HOST_VARS_DIR/$TARGET_HOSTNAME/$TARGET_HOSTNAME.yml" <<EOF
---
ansible_ssh_private_key_file: "${TARGET_ANSIBLEUSER_SSH_PRIVATE_KEY_FILE:-''}"
ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
ansible_become: true
ansible_become_method: sudo
ansible_become_password: "${TARGET_ANSIBLEPASS:-'password'}"
ansible_host: "${TARGET_ANSIBLE_HOST:-}"
ansible_distribution: "${TARGET_ANSIBLE_DISTRIBUTION:-'Ubuntu'}"
hostname: "${TARGET_HOSTNAME:-'default-hostname'}"
ansible_user: "${TARGET_ANSIBLEUSER:-'ansible'}"
ansible_password: "${TARGET_ANSIBLEPASS:-'password'}"
adminuser: "${TARGET_ADMINUSER:-'admin'}"
adminpwd: "${TARGET_ADMINPASS:-'password'}"
deployment_source: "$DEPLOYMENT_SOURCE"
dockercompose_local_location: "$DOCKERCOMPOSE_LOCAL_LOCATION"
docker_compose_path: "$DOCKER_COMPOSE_PATH"
docker_repo_tag: "${DOCKER_REPO_TAG:-'main'}"
docker_composition_repo: "${DOCKER_COMPOSITION_REPO:-https://github.com/pvarki/docker-rasenmaeher-integration.git}"
dns_wanted: "${DO_YOU_WANT_TO_USE_DNS}"
dns_zone_name: "${DNS_ZONE_NAME:-'pvarki.fi'}"
dns_record_name: "${DNS_RECORD_NAME:-$TARGET_HOSTNAME.pvarki.fi}"
dns_provider_url: "${DNS_PROVIDER_URL}"
dns_api_token: "${DNS_API_TOKEN}"
EOF

# Create host_vars file for the control node needed vars
cat > "$HOST_VARS_DIR/localhost.yml" <<EOF
---
ansible_become_password: "${LOCALHOST_BECOME_PASSWORD:-'password'}"
EOF

# Create group_vars file for group-specific variables
cat > "$GROUP_VARS_DIR/$TARGET_HOSTNAME.yml" <<EOF
---
EOF

# Create or update hosts.yml in the main inventory directory
cat > "$INV_DIR/hosts.yml" <<EOF
all:
  children:
    ${ENVIRONMENT_STAGE:-staging}:
      hosts:
        ${TARGET_HOSTNAME:?'Hostname required'}:
          ansible_host: ${TARGET_ANSIBLE_HOST:-'localhost'}
EOF

echo "Written vars from environment."

# Encrypt the host_vars and group_vars files using Ansible Vault
if [ ! -z "$ANSIBLE_VAULT_PASSWORD" ]; then
    echo "$ANSIBLE_VAULT_PASSWORD" > vault_pass.txt
    chmod 600 vault_pass.txt
    VAULT_ID="default"
    ansible-vault encrypt "$HOST_VARS_DIR/$TARGET_HOSTNAME/$TARGET_HOSTNAME.yml" --vault-password-file vault_pass.txt --encrypt-vault-id $VAULT_ID
    if [ $? -eq 0 ]; then
        echo "Encrypted vars for $TARGET_HOSTNAME using Ansible Vault with vault-id $VAULT_ID."
    else
        echo "Failed to encrypt vars. Check the vault setup."
        exit 1
    fi
    # Update ansible.cfg to use the vault password file
    cat > ansible.cfg <<EOF
[defaults]
inventory = ./inventory/hosts.yml
vault_password_file = ./vault_pass.txt
host_key_checking = False
EOF
    echo "Updated ansible.cfg with vault password file."
else
    echo "Vault password not set. Skipping encryption."
fi

echo "Inventory for $TARGET_HOSTNAME has been set up in $INV_DIR."
echo ""
echo "Ready."
