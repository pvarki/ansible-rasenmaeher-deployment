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
echo "| |_/ // /_\ \\ \`--.| |__  |  \| || .  . |/ /_\ \| |__  | |_| || |__  | |_/ /"
echo "|    / |  _  | \`--. \|  _| | . \`|| |\/| ||  _  ||  __| |  _  ||  __| |    / "
echo "| |\ \ | | | |/\__/ /| |___ | |\  || |  | || | | || |___ | | | || |___ | |\ \ "
echo "\_|_\_|\_| |_/\____/ \____/ \_|_\_/\_|  |_/\_|_|_/\____/ \_| |_/\____/ \_| \_|"
echo " / _ \ | \ | |/  ___||_   _|| ___ \| |    |  ___|                             "
echo "/ /_\ \|  \| |\ \`--.   | |  | |_/ /| |    | |__                               "
echo "|  _  || . \` | \`--. \  | |  | ___ \| |    |  __|                              "
echo "| | | || |\  |/\__/ / _| |_ | |_/ /| |____| |___                              "
echo "\_| |_/\_| \_/\____/  \___/ \____/ \_____/\____/                              "
echo "                                                                              "
echo "                                                                             "
echo "Version: 24 April 2024"
echo ""

echo "Installing ansible-galaxy roles..."
ansible-galaxy install -r requirements.yml
ansible-galaxy collection install community.docker

if [ "$OPENVPN_WANTED" == "yes" ]; then
    echo "Openvpn wanted, installing role from Ansible Galaxy..."
    ansible-galaxy install kyl191.openvpn
    echo "kyl191.openvpn role installed."
fi

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

# Declare an associative array for secrets
secrets_file="$TARGET_HOST_VARS_DIR/rasenmaeher_secrets.yml"
declare -A secrets=(
    ["keycloak_database_password"]="$KEYCLOAK_DATABASE_PASSWORD"
    ["rm_database_password"]="$RM_DATABASE_PASSWORD"
    ["tak_database_password"]="$TAK_DATABASE_PASSWORD"
    ["postgres_password"]="$POSTGRES_PASSWORD"
    ["ldap_admin_password"]="$LDAP_ADMIN_PASSWORD"
    ["keycloak_admin_password"]="$KEYCLOAK_ADMIN_PASSWORD"
    ["keycloak_management_password"]="$KEYCLOAK_MANAGEMENT_PASSWORD"
    ["takserver_cert_pass"]="$TAKSERVER_CERT_PASS"
    ["tak_ca_pass"]="$TAK_CA_PASS"
)

# Begin the secrets array in the YAML file
echo "secrets:" > "$secrets_file"
echo "  {" >> "$secrets_file"

# Counter and total for comma handling
total=${#secrets[@]}
counter=1

# Manage secrets from env
for key in "${!secrets[@]}"; do
    # Generate a new secret if it's not set in the .env
    if [ -z "${secrets[$key]}" ]; then
        secrets[$key]=$(openssl rand -hex 8)  # Using openssl to generate a random hex string
    fi
    # Check if this is the last key to avoid trailing comma
    if [[ $counter -eq $total ]]; then
        echo "  ${key}: \"${secrets[$key]}\"" >> "$secrets_file"
    else
        echo "  ${key}: \"${secrets[$key]}\"," >> "$secrets_file"
    fi
    ((counter++))
done

# Close the curly brace for the secrets dictionary
echo "  }" >> "$secrets_file"


# Write other environment variables to a host_vars file
cat > "$HOST_VARS_DIR/$TARGET_HOSTNAME/$TARGET_HOSTNAME.yml" <<EOF
---
ansible_ssh_private_key_file: "${TARGET_ANSIBLE_SSH_PRIVATE_KEY_FILE:-''}"
ansible_ssh_public_key_file: "${TARGET_ANSIBLE_SSH_PRIVATE_KEY_FILE:-''}.pub"
ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
ansible_become: true
ansible_become_method: sudo
ansible_become_password: "${TARGET_ANSIBLEPASS:-'password'}"
ansible_host: "${TARGET_ANSIBLE_HOST:-}"
ansible_distribution: "${TARGET_ANSIBLE_DISTRIBUTION:-'Ubuntu'}"
hostname: "${TARGET_HOSTNAME:-'default-hostname'}"
ansible_user: "${TARGET_ANSIBLEUSER:-'ansible'}"
adminuser: "${TARGET_ADMINUSER:-'admin'}"
adminpwd: "${TARGET_ADMINPASS:-'password'}"
deployment_source: "$DEPLOYMENT_SOURCE"
deploy_in_dev: "${DEPLOY_IN_DEV:-false}"
dockercompose_local_location: "$DOCKERCOMPOSE_LOCAL_LOCATION"
docker_compose_path: "$DOCKER_COMPOSE_PATH"
docker_repo_tag: "${DOCKER_REPO_TAG:-'main'}"
docker_composition_repo: "${DOCKER_COMPOSITION_REPO:-https://github.com/pvarki/docker-rasenmaeher-integration.git}"
build_locally: "${BUILD_LOCALLY:-'false'}"
server_domain: "${SERVER_DOMAIN:-'localmaeher.pvarki.fi'}"
additional_subdomain: "${ADDITIONAL_SUBDOMAIN}"
cfssl_ca_name: "${CFSSL_CA_NAME:-'localmaeher'}"
mw_le_email: "${MW_LE_EMAIL:-'example@example.com'}"
mw_le_test: "${MW_LE_TEST:-'true'}"
openvpn_wanted: "${OPENVPN_WANTED:-'false'}"
openvpn_custom_dns: "${OPENVPN_CUSTOM_DNS}"
server_ip: "${SERVER_IP:-127.0.0.1}"
EOF

echo "Finished writing YAML file: $HOST_VARS_DIR/$TARGET_HOSTNAME/$TARGET_HOSTNAME.yml"
cat "$HOST_VARS_DIR/$TARGET_HOSTNAME/$TARGET_HOSTNAME.yml"

# Conditionally add dy.fi DDNS vars if ddns deploy is true
if [ "${USE_DDNS:-false}" = "true" ]; then
    cat >> "$HOST_VARS_DIR/$TARGET_HOSTNAME/$TARGET_HOSTNAME.yml" <<EOF
dyuser: "$DEPLOYMENT_SOURCE"
dypassword: "${DEPLOY_IN_DEV:-false}"
ddns_domainname: "${SERVER_DOMAIN}"
EOF
fi

# Create host_vars file for the control node needed vars
cat > "$HOST_VARS_DIR/localhost.yml" <<EOF
---
ansible_user: "${LOCALHOST_USER:-'user'}"
target_ansible_user: "${TARGET_ANSIBLEUSER:-'ansibleuser'}"
ansible_become_password: "${LOCALHOST_BECOME_PASSWORD:-'password'}"
ansible_become: true
ansible_become_method: sudo
ansible_ssh_private_key_file: "${TARGET_ANSIBLE_SSH_PRIVATE_KEY_FILE:-''}"
ansible_ssh_public_key_file: "${TARGET_ANSIBLE_SSH_PRIVATE_KEY_FILE:-''}.pub"
local_user: "${LOCALHOST_USER:-'user'}"
server_domain: "${SERVER_DOMAIN:-'localmaeher.pvarki.fi'}"
additional_subdomain: "${ADDITIONAL_SUBDOMAIN}"
target_address: "${TARGET_ANSIBLE_HOST:-''}"
EOF

# Create host_vars file for the DNS server
cat > "$HOST_VARS_DIR/dns-server.yml" <<EOF
---
ansible_host: "${TARGET_ANSIBLE_HOST:-}"
ansible_distribution: "${TARGET_ANSIBLE_DISTRIBUTION:-'Windows'}"
ansible_user: "${DNSHOST_ANSIBLE_USER:-'ansible'}"
ansible_become: true
ansible_become_method: sudo
ansible_ssh_private_key_file: "${DNS_SERVER_ANSIBLEUSER_SSH_PRIVATE_KEY_FILE:-''}"
hostname: "${DNS_SERVER_HOST:-'dns-server'}"
ansible_become_password: "${DNSHOST_BECOME_PASSWORD:-'password'}"
EOF

# Conditionally add Windows-specific variables if windows_server_dns is true
if [ "${WINDOWS_SERVER_DNS:-false}" = "true" ]; then
    cat >> "$HOST_VARS_DIR/dns-server.yml" <<EOF
ansible_connection: winrm
ansible_winrm_transport: ntlm
ansible_winrm_server_cert_validation: ignore
EOF
fi

# Create group_vars file for group-specific variables
cat > "$GROUP_VARS_DIR/$TARGET_HOSTNAME.yml" <<EOF
---
dns_wanted: "${DO_YOU_WANT_TO_USE_DNS}"
dns_zone_name: "${DNS_ZONE_NAME:-'pvarki.fi'}"
dns_record_name: "${DNS_RECORD_NAME:-$TARGET_HOSTNAME.pvarki.fi}"
dns_provider_url: "${DNS_PROVIDER_URL}"
dns_api_token: "${DNS_API_TOKEN}"
windows_server_dns: "${WINDOWS_SERVER_DNS:-false}"
deployment_name: "${SERVER_DOMAIN:-'localmaeher.pvarki.fi'}"
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
