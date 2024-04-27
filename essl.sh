#!/bin/bash

print() {
    message="$1"
    echo -e "\e[94m$message\e[0m"
}

success() {
    message="$1"
    echo -e "\e[1;94m$message\e[0m"
}

error() {
    message="$1"
    echo -e "\e[91m$message\e[0m"
}

input() {
    message="$1"
    name="$2"
    read -p "$(echo -e '\e[33m'"$message"'\e[0m')" "$name"
}

validate_domain() {
    while true; do
        input $'\e[33mPlease enter your domain: \e[0m' 'domain'
        if [[ "$domain" =~ .*\..* && ${#domain} -ge 3 ]]; then
            return 0
        else
            error "Invalid domain format. Please enter a valid domain name."
        fi
    done
}

validate_email() {
    while true; do
        input $'\e[33mPlease enter your email: \e[0m' 'email'
        if [[ "$email" =~ .*@.*\..* && ${#email} -gt 5 ]]; then
            return 0
        else
            error "Invalid email format. Please enter a valid email address."
        fi
    done
}

set_directory() {
    address="$1"
    if [ -d "$address" ]; then
        print "deleted $address directory and mkdir again."
        rm -rf "$address" || { error "Error removing existing directory"; exit 1; }
    fi
    mkdir -p "$address" || { error "Error creating directory"; exit 1; }
}

install_acme() {
    command -v ~/.acme.sh/acme.sh &>/dev/null || {
        curl https://get.acme.sh | sh || { error "Error installing acme.sh, try again"; exit 1; }
    }
}

install_certbot() {
    if [ -x "$(command -v apt)" ]; then
        sudo apt install -y snapd || { error "Error installing snapd, try again"; exit 1; }
        sudo apt remove -y certbot || { error "Error removing old certbot, try again"; exit 1; }
        sudo snap install certbot --classic || { error "Error installing certbot via snap, try again"; exit 1; }
    elif [ -x "$(command -v yum)" ]; then
        sudo yum -y install epel-release
        sudo yum -y install certbot python2-certbot-nginx
    elif [ -x "$(command -v pacman)" ]; then
        sudo pacman -Sy --noconfirm certbot
    else
        error "Unsupported operating system."
        exit 1
    fi
}

update_packages() {
    if [ -x "$(command -v apt)" ]; then
        apt update && apt install -y socat
    elif [ -x "$(command -v yum)" ]; then
        yum -y update && yum -y install socat
    elif [ -x "$(command -v dnf)" ]; then
        dnf -y update && dnf -y install socat
    elif [ -x "$(command -v pacman)" ]; then
        pacman -Sy --noconfirm socat
    else
        error "Unsupported operating system."
    fi
}

#get_single_ssl_acme() {
#    local domain="$1"
#    local email="$2"
#    local address="/root/certs/$domain"
#    set_directory "$domain"
#    export DOMAIN="$domain"
#    if ~/.acme.sh/acme.sh \
#        --issue --force --standalone -d "$DOMAIN" \
#        --httpport 80 \
#        --fullchain-file "$address/$DOMAIN.cer" \
#        --key-file "$address/$DOMAIN.cer.key"; then
#        success "\n\n\tSSL certificate for domain '$domain' successfully obtained."
#        success "\t\tYour SSL is located in: $address\n\n\n"
#    else
#        error "\n\tFailed to obtain SSL certificate for domain '$domain'.\n"
#        error "\n\t\tTrying with certbot...\n\n"
#        get_single_ssl_certbot "$domain" "$email"
#    fi
#}

#get_wildcard_ssl_acme() {
#    local domain="$1"
#    local email="$2"
#    local address="/root/certs/$domain"
#    set_directory "$domain"
#    export DOMAIN="$domain"
#    
#    txt_value=$(cat /root/.acme.sh/"$DOMAIN"_ecc/"$DOMAIN".txt)
#    print "\nPlease set the following TXT record in your DNS settings:\n"
#    print "\tName: _acme-challenge.$DOMAIN"
#    print "\tText Value: $txt_value\n"
#    
#    ~/.acme.sh/acme.sh --issue -d $DOMAIN --dns \
#     --yes-I-know-dns-manual-mode-enough-go-ahead-please
#    
#    if [ $? -eq 0 ]; then
#        input '\nPlease set the name and text value in your DNS record...\n\n\tAfter setting, enter y/Y to confirm: ' 'set_txt'
#        
#        if [ "$set_txt" == "y" ] || [ "$set_txt" == "Y" ]; then
#            ~/.acme.sh/acme.sh --renew -d $DOMAIN \
#            --yes-I-know-dns-manual-mode-enough-go-ahead-please
#            success "\n\n\tSSL certificate for domain '$domain' successfully obtained."
#        else
#            error "\n\tYou chose not to proceed with setting up the DNS. SSL certificate issuance for domain '$domain' aborted.\n"
#        fi
#    else
#        error "\n\tFailed to obtain SSL certificate for domain '$domain'. Please check your DNS configuration and try again.\n"
#    fi
#}


get_single_ssl_certbot() {
    local domain="$1"
    local email="$2"
    local fullchain_src="/etc/letsencrypt/live/$domain/fullchain.pem"
    local privkey_src="/etc/letsencrypt/live/$domain/privkey.pem"
    local retry_count=0
    local max_retries=2
    
    while [ $retry_count -lt $max_retries ]; do
        if sudo certbot certonly --standalone -d "$domain"; then
            success "\n\n\tSSL certificate for domain '$domain' successfully obtained."
            move_ssl_files "$domain" "$fullchain_src" "$privkey_src"
            return 0
        else
            ((retry_count++))
            error "\n\tFailed to obtain SSL certificate for domain '$domain'. Retrying ($retry_count of $max_retries)...\n\n"
            sleep 5
        fi
    done
    
    error "\n\tFailed to obtain SSL certificate for domain '$domain' after $max_retries attempts.\n\n"
    return 1
}


get_wildcard_ssl_certbot() {
    local domain="$1"
    local email="$2"    
    local retry_count=0
    local max_retries=2
    
    while [ $retry_count -lt $max_retries ]; do
        if sudo certbot certonly --manual --preferred-challenges=dns -d "*.$domain" --agree-tos --email "$email"; then
            success "\n\n\tSSL certificate for domain '*.$domain' successfully obtained."
            move_ssl_files "*.$domain" "/etc/letsencrypt/live/$domain/fullchain.pem" "/etc/letsencrypt/live/$domain/privkey.pem"
            return 0
        else
            ((retry_count++))
            error "\n\tFailed to obtain SSL certificate for domain '*.$domain'. Retrying ($retry_count of $max_retries)...\n\n"
        fi
    done
    
    error "\n\tFailed to obtain SSL certificate for domain '*.$domain' after $max_retries attempts. Please check your DNS configuration and try again.\n"
    return 1
}

domain_list() {
    print "\nFirst, please check your domain's list:\n"
    if ! certbot certificates | grep -q "No certificates found"; then
        certbot certificates
        input "\nEnter fullchain.pem cert address: " "dir_path"
        revoke_ssl_certbot "$dir_path"
    else
        error "\nYou don't have any domains.\n"
    fi
}

revoke_ssl_certbot() {
    local dir_path="$1"
    sudo certbot revoke --cert-path "$dir_path" --non-interactive
    if [ $? -eq 0 ]; then
        success "\n\n\tCertificate successfully revoked.\n\n"
        directory=$(dirname $(realpath "$dir_path"))
        rm -rf $directory

    else
        error "\n\tFailed to revoke certificate.\n\n"
    fi
}


renew_ssl_cert() {
    local domain="$1"
    certbot renew --cert-name "$domain"
    if [ $? -eq 0 ]; then
        echo "SSL certificate for domain '$domain' has been successfully renewed."
    else
        echo "Failed to renew the SSL certificate for domain '$domain'. Please check your configuration and try again."
    fi
}

get_destination_directory() {
    local domain="$1"
    while true; do
        input "\nEnter the destination directory path: " "dest_dir"
        if [ -z "$dest_dir" ]; then
            error "Destination directory cannot be empty."
        elif [[ ! "$dest_dir" == /* ]]; then
            error "Destination directory must start with '/'."
        elif [[ "$dest_dir" == */ || "$dest_dir" == *//* ]]; then
            error "Invalid destination directory format. Please avoid trailing '/' and consecutive '/'."
        else
            address="$dest_dir/$domain"
            set_directory $address
            break
        fi
    done
}



move_ssl_files() {
    local domain="$1"
    local fullchain_src="$2"
    local privkey_src="$3"
    print "\n\n\nWhere would you like to move the SSL certificate files for domain '$domain'?\n"
    print "1. Custom directory"
    print "2. Default directory 'marzban'"
    print "3. Default directory 'all 3x-ui/s-ui/hiddify'"
    input "\nEnter your choice (1, 2, 3): " "choice"
    case $choice in
        1)
            get_destination_directory "$domain"
            ;;
        2)
            dest_dir="/var/lib/marzban/certs/$domain"
            set_directory "$dest_dir"
            ;;
        3)
            dest_dir="/root/certs/$domain"
            set_directory "$dest_dir"
            ;;
        *)
            error "Invalid choice. Please enter 1, 2, or 3."
            return 1
            ;;
    esac
    sudo cp "$fullchain_src" "$dest_dir/$domain/fullchain.pem" || { error "Error copying certificate files"; return 1; }
    sudo cp "$privkey_src" "$dest_dir/$domain/privkey.pem" || { error "Error copying certificate files"; return 1; }

    success "SSL certificate files for domain '$domain' successfully moved to: $dest_dir/$domain"
}

get_multi_domain_ssl_certbot() {
    local domains="$1"
    local email="$2"
    local domain_args=""
    local fullchain_src=""
    local privkey_src=""

    for domain in $domains; do
        domain_args+=" -d $domain"
    done

    if sudo certbot certonly --standalone $domain_args --email $email --non-interactive; then
        success "\n\n\tSSL certificate for domains '$domains' successfully obtained."
        
        for domain in $domains; do
            fullchain_src="/etc/letsencrypt/live/$domain/fullchain.pem"
            privkey_src="/etc/letsencrypt/live/$domain/privkey.pem"
            move_ssl_files "$domain" "$fullchain_src" "$privkey_src"
            break
        done
    else
        error "\n\tFailed to obtain SSL certificate for domains '$domains'.\n"
    fi
}



#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

clear ; update_packages ; install_certbot ; install_acme ; clear

print "\n\n\t Welcome to ESSL"
print "\t\t v2.0.0 by @ErfJab\n\n"

while true; do
    print "-------------------------------------------------------"
    print "1) new Single Domain ssl (sub.domain.com)"
    print "2) new Wildcard ssl (*.domain.com)"
    print "3) new Multi-Domain ssl (sub.domain1.com, sub2.domain2.com ...)"
    print "4) renewal ssl (update)" 
    print "5) revoke ssl (delete)"
    print "0) Exit"
    input '\nPlease Select your option: ' 'option'
    
    clear

    if [ "$option" == "1" ]; then
        validate_domain
        validate_email
        clear
        get_single_ssl_certbot "$domain" "$email"

    elif [ "$option" == "2" ]; then
        validate_domain
        validate_email
        clear
        get_wildcard_ssl_certbot "$domain" "$email"

    elif [ "$option" == "3" ]; then
        validate_domain
        validate_email
        clear
        get_multi_domain_ssl_certbot "$domain" "$email"

    elif [ "$option" == "4" ]; then
        validate_domain
        renew_ssl_cert "$domain"

    elif [ "$option" == "5" ]; then
        domain_list

    elif [ "$option" == "0" ]; then
        clear
        exit 1

    else
        error "Invalid input. Please select a valid option.\n\n"
    fi
done
