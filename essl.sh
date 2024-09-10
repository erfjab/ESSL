#!/bin/bash

# Function definitions for colored output
colors=( "\033[1;31m" "\033[1;35m" "\033[1;92m" "\033[38;5;46m" "\033[1;38;5;208m" "\033[1;36m" "\033[0m" )
red=${colors[0]} pink=${colors[1]} green=${colors[2]} spring=${colors[3]} orange=${colors[4]} cyan=${colors[5]} reset=${colors[6]}
print() { echo -e "${cyan}$1${reset}"; }
error() { echo -e "${red}✗ $1${reset}"; }
success() { echo -e "${spring}✓ $1${reset}"; }
log() { echo -e "${green}! $1${reset}"; }
warn() { echo -e "${orange} $1${reset}"; }

# Trap for script interruption
trap 'echo -e "\n${red}Script interrupted!${reset}"; exit 1' SIGINT

# Validate domain format
validate_domain() {
    if [[ ! "$1" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        error "Invalid domain format: $1"
        return 1
    fi
    return 0
}

# Function to install necessary dependencies
install_dependencies() {
    local pkg_manager
    if command -v apt-get &> /dev/null; then
        pkg_manager="apt-get"
    elif command -v dnf &> /dev/null; then
        pkg_manager="dnf"
    elif command -v yum &> /dev/null; then
        pkg_manager="yum"
    else
        error "No supported package manager found. Please install packages manually."
        exit 1
    fi

    log "Updating package lists..."
    $pkg_manager update -y || warn "Failed to update package lists."

    local packages=("curl" "socat" "certbot")
    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            log "Installing $pkg..."
            $pkg_manager install -y "$pkg" || error "Failed to install $pkg"
        fi
    done

    if ! command -v acme.sh &> /dev/null; then
        log "Installing acme.sh..."
        curl https://get.acme.sh | sh -s email="$email" || error "Failed to install acme.sh"
        source ~/.bashrc
    fi

    success "Dependencies are installed."
}

# Function to obtain and install SSL certificate using acme.sh for multiple domains
get_install_certificate_acme() {
    local domains=("$@")
    local domain_args=""
    local main_domain="${domains[0]}"

    for domain in "${domains[@]}"; do
        domain=$(echo "$domain" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
        domain_args+=" -d $domain"
    done

    ~/.acme.sh/acme.sh --issue --standalone $domain_args --accountemail "$email" || return 1

    local cert_dir="$destination"
    mkdir -p "$cert_dir" || error "Failed to create certificate directory"

    ~/.acme.sh/acme.sh --install-cert -d "$main_domain" \
        --key-file "$cert_dir/privkey.pem" \
        --fullchain-file "$cert_dir/fullchain.pem" || return 1

    success "SSL certificate obtained and installed using acme.sh for domains: ${domains[*]}"
    return 0
}

# Function to obtain and install SSL certificate using certbot for multiple domains
get_install_certificate_certbot() {
    local domains=("$@")
    local domain_args=""

    for domain in "${domains[@]}"; do
        domain=$(echo "$domain" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
        domain_args+=" -d $domain"
    done

    certbot certonly --standalone $domain_args --non-interactive --agree-tos --email "$email" || return 1

    local main_domain="${domains[0]}"
    local cert_dir="$destination"
    mkdir -p "$cert_dir" || error "Failed to create certificate directory"

    cat /etc/letsencrypt/live/$main_domain/privkey.pem > "$cert_dir/privkey.pem"
    cat /etc/letsencrypt/live/$main_domain/fullchain.pem > "$cert_dir/fullchain.pem"

    success "SSL certificate obtained and installed using certbot for domains: ${domains[*]}"
    return 0
}

# Function to install the ESSL script
install_script() {
    log "Installing ESSL script..."
    local install_dir="/usr/local/bin"
    local script_path="$install_dir/essl"

    curl -s -o "$script_path" https://raw.githubusercontent.com/erfjab/ESSL/master/essl.sh
    chmod +x "$script_path"
    success "ESSL script installed successfully."
}

# Function to upgrade the ESSL script
upgrade_script() {
    log "Upgrading ESSL script..."
    local install_dir="/usr/local/bin"
    local script_path="$install_dir/essl"

    if [ -f "$script_path" ]; then
        curl -s -o "$script_path" https://raw.githubusercontent.com/erfjab/ESSL/master/essl.sh
        chmod +x "$script_path"
        success "ESSL script upgraded successfully."
    else
        error "ESSL script not found. Use '--install' to install it first."
    fi
}

# Function to display help message
show_help() {
    cat << EOF
    
Usage: essl [email] [domain1 domain2 ...] <destination> | --install | --upgrade

Email:
  Provide an email address to use with acme.sh and certbot.

Domains:
  You can provide one or more domains.

Destination:
  Use 'marzban', 'x-ui', '3x-ui', 's-ui', or 'hiddify' for predefined paths,
  or provide a custom path starting with '/'.

Commands:
  --install     Install the ESSL script.
  --upgrade     Upgrade the ESSL script to the latest version.
  --help        Show this help message.
  --version     Show script version

Examples:
  essl user@example.com example.com /etc/ssl/certs
  essl user@example.com domain1.com domain2.com domain3.com /custom/path
  essl --install
  essl --upgrade

Note: This script must be run as root.

EOF
}

# Main function to handle the script logic
main() {
    [ "$EUID" -eq 0 ] || { error "This script must be run as root."; exit 1; }

    # Handle --install and --upgrade options
    case "$1" in
        --install)
            install_script
            exit 0
            ;;
        --upgrade)
            upgrade_script
            exit 0
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        --version|-v)
            print "currect essl version: v3.0.2"
            exit 0
            ;;esac

    # Check if user provided enough arguments for SSL installation
    if [ $# -lt 3 ]; then
        error "Not enough arguments provided. Use 'essl --help' for more details."
        exit 1
    fi

    # Get email and domain arguments
    email="$1"
    shift
    local destination="${@: -1}"
    local domains=("${@:1:$#-1}")

    # Validate and handle the domains
    for domain in "${domains[@]}"; do
        validate_domain "$domain" || exit 1
    done

    # Set predefined paths if necessary
    case "$destination" in
        marzban) destination="/var/lib/marzban/certs" ;;
        x-ui|3x-ui|s-ui|hiddify) destination="/certs" ;;
        *) [[ "$destination" == /* ]] || { error "Invalid destination path. Must start with '/'"; exit 1; } ;;
    esac
    [[ "$destination" != */ ]] && destination="${destination}/"

    # Install dependencies
    install_dependencies

    # Try acme.sh first
    if get_install_certificate_acme "${domains[@]}"; then
        log "Certificate successfully obtained using acme.sh"
    else
        warn "Failed to obtain certificate using acme.sh. Trying certbot..."
        if get_install_certificate_certbot "${domains[@]}"; then
            log "Certificate successfully obtained using certbot"
        else
            error "Failed to obtain certificate using both acme.sh and certbot"
            exit 1
        fi
    fi

    # Display final certificate path
    success "Certificate files are located at:"
    print "⭐ Private key: ${destination}privkey.pem"
    print "⭐ Full chain: ${destination}fullchain.pem"
}

# If no arguments are provided, show help
if [ $# -eq 0 ]; then
    show_help
else
    main "$@"
fi