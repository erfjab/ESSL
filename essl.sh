#!/bin/bash

print() {
    echo -e "\e[94m"$1"\e[0m"
}

error() {
    echo -e "\e[1;91m[error] "$1"\e[0m"
}

success() {
    echo -e "\e[1;94m[success] "$1"\e[0m"
}

input() {
    read -p "$(echo -e '\e[33m'"$1"'\e[0m')" "$2"
}

update_packages() {
    if command -v apt &>/dev/null; then
        apt update && apt install -y socat
    elif command -v yum &>/dev/null; then
        yum -y update && yum -y install socat
    elif command -v dnf &>/dev/null; then
        dnf -y update && dnf -y install socat
    elif command -v pacman &>/dev/null; then
        pacman -Sy --noconfirm socat
    else
        error "Unsupported operating system."
        exit 1
    fi
}

install_certbot() {
    if ! command -v certbot &>/dev/null; then
        if command -v apt &>/dev/null; then
            apt install -y certbot
        elif command -v yum &>/dev/null; then
            yum -y install certbot
        elif command -v dnf &>/dev/null; then
            dnf -y install certbot
        elif command -v pacman &>/dev/null; then
            pacman -Sy --noconfirm certbot
        else
            error "Certbot installation failed. Unsupported operating system."
            exit 1
        fi
    fi
}

install_acme() {
    if ! command -v ~/.acme.sh/acme.sh &>/dev/null; then
        curl https://get.acme.sh | sh || { error "Error installing acme.sh, check logs..."; exit 1; }
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    fi
}

validate_domain() {
    while true; do
        input "Please enter your domain: " 'domain'
        if [[ "$domain" =~ .*\..* && ${#domain} -ge 3 ]]; then
            return 0
        else
            error "Invalid domain format. Please enter a valid domain name."
        fi
    done
}

validate_email() {
    while true; do
        input "Please enter your email: " 'email'
        if [[ "$email" =~ .*@.*\..* && ${#email} -gt 5 ]]; then
            return 0
        else
            error "Invalid email format. Please enter a valid email address."
        fi
    done
}

validate_apikey() {
    while true; do
        input "Please enter your Global API key: " "api_key"
        if [[ -n "$api_key" ]]; then
            break
        else
            error "API key cannot be empty. Please enter a valid API key."
        fi
    done
}

set_directory() {
    address="$1"
    if [ -d "$address" ]; then
        rm -rf "$address" || { error "Error removing existing directory"; exit 1; }
    fi
    mkdir -p "$address" || { error "Error creating directory"; exit 1; }
}

move_ssl_files_combined() {
    local domain="$1"
    local type="$2"
    local dest_dir=""
    
    while true; do
        print "\n\n\nMoved to?\n"
        print "1. Custom directory"
        print "2. Marzban panel directory "
        print "3. 3x-ui/x-ui/s-ui/hiddify panel directory"
        input "\nEnter your choice (1, 2, 3): " "choice"
        case $choice in
            1)
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
                        set_directory "$address"
                        break
                    fi
                done
                ;;
            2)
                dest_dir="/var/lib/marzban/certs/$domain"
                set_directory "$dest_dir"
                ;;
            3)
                dest_dir="/certs/$domain"
                set_directory "$dest_dir"
                ;;
            *)
                error "Invalid choice. Please enter 1, 2, or 3."
                continue
                ;;
        esac

        if [ ! -d "$dest_dir" ] || [ ! -w "$dest_dir" ]; then
            error "Directory '$dest_dir' either does not exist or is not writable."
            continue
        fi

        if [ "$type" == "acme" ]; then
            if [ ! -f ~/.acme.sh/"${domain}_ecc"/fullchain.cer ] || [ ! -f ~/.acme.sh/"${domain}_ecc"/"${domain}".key ]; then
                error "Certificate files not found in the '~/.acme.sh/${domain}_ecc/' directory."
                break
            fi
        elif [ "$type" == "certbot" ]; then
            if [ ! -f /etc/letsencrypt/live/"$domain"/fullchain.pem ] || [ ! -f /etc/letsencrypt/live/"$domain"/privkey.pem ]; then
                error "Certificate files not found in the '/etc/letsencrypt/live/$domain/' directory."
                break
            fi
        fi

        if [ "$type" == "acme" ]; then
            sudo cp "$HOME/.acme.sh/${domain}_ecc/fullchain.cer" "$dest_dir/fullchain.cer" || { error "Error copying certificate files"; return 1; }
            sudo cp "$HOME/.acme.sh/${domain}_ecc/${domain}.key" "$dest_dir/privkey.key" || { error "Error copying certificate files"; return 1; }
        elif [ "$type" == "certbot" ]; then
            sudo cp "/etc/letsencrypt/live/$domain/fullchain.pem" "$dest_dir/fullchain.pem" || { error "Error copying certificate files"; return 1; }
            sudo cp "/etc/letsencrypt/live/$domain/privkey.pem" "$dest_dir/privkey.pem" || { error "Error copying certificate files"; return 1; }
        fi
        success "SSL certificate files for domain '$domain' successfully moved.\n\n\t⭐ SSL location: $dest_dir\n\n\tfullchain: $dest_dir/fullchain.cer\n\tkey file : $dest_dir/privkey.key\n\n"
        break
    done
}

get_single_ssl() {
    local domain="$1"
    local email="$2"
    if sudo ~/.acme.sh/acme.sh --issue --force --standalone -d "$domain"; then
        success "\n\n\t⭐ SSL certificate for domain '$domain' successfully obtained."
        move_ssl_files_combined "$domain" "acme"
    elif sudo certbot certonly --standalone -d "$domain"; then
        success "\n\n\t⭐ SSL certificate for domain '$domain' successfully obtained."
        move_ssl_files_combined "$domain" "certbot"
    else
        error "Failed to obtain SSL certificate for domain '$domain'. Please check your DNS configuration and try again.\n"
    fi
}

get_multi_domain_ssl() {
    local domains="$1"
    local email="$2"
    local domain_args=""

    for domain in $domains; do
        domain_args+=" -d $domain"
    done

    if sudo certbot certonly --standalone $domain_args --email $email --non-interactive; then
        success "\n\n\t⭐ SSL certificate for domains '$domains' successfully obtained."
        for domain in $domains; do
            move_ssl_files_combined "$domain" "certbot"
            break
        done
    elif sudo ~/.acme.sh/acme.sh --issue --force --standalone $domain_args; then
        success "\n\n\t⭐ SSL certificate for domains '$domains' successfully obtained."
        for domain in $domains; do
            move_ssl_files_combined "$domain" "acme"
            break
        done
    else
        error "\n\tFailed to obtain SSL certificate for domains '$domains'.\n"
    fi
}

get_wildcard_ssl() {
    local domain="$1"
    local email="$2"
    if sudo certbot certonly --manual --preferred-challenges=dns -d "*.$domain" --agree-tos --email "$email";then
        success "\n\n\t⭐ SSL certificate for domain '*.$domain' successfully obtained."
        move_ssl_files_combined "*.$domain" "certbot"
        return 0
    else
        error "Failed to obtain SSL certificate for domain '$domain'. Please check your DNS configuration and try again.\n"
    fi
}

revoke_ssl() {
    local domain="$1"
    local ssl_path="/etc/letsencrypt/live/$domain/fullchain.pem"

    if [ -f "$ssl_path" ]; then
        if sudo certbot revoke --cert-path "$ssl_path"; then
            success "SSL certificate for domain '$domain' revoked successfully."
        else
            error "Failed to revoke SSL certificate for domain '$domain'."
        fi
    elif sudo ~/.acme.sh/acme.sh --revoke -d "$domain"; then
        success "SSL certificate for domain '$domain' revoked successfully."
    else
        error "No SSL certificate found for domain '$domain'."
    fi
}

renew_ssl() {
    local domain="$1"
    local ssl_type=""
    
    if sudo certbot certificates --cert-name "$domain" | grep -q "Certificate Name: $domain"; then
        ssl_type="certbot"
    elif [ -f "~/.acme.sh/${domain}/${domain}.cer" ]; then
        ssl_type="acme"
    else
        error "No SSL certificate found for domain '$domain'."
        return 1
    fi
    
    if [ "$ssl_type" == "certbot" ]; then
        if sudo certbot renew --cert-name "$domain"; then
            success "SSL certificate for domain '$domain' renewed successfully."
        else
            error "Failed to renew SSL certificate for domain '$domain' using Certbot. check logs..."
        fi
    elif [ "$ssl_type" == "acme" ]; then
        if sudo ~/.acme.sh/acme.sh --renew -d "$domain"; then
            success "SSL certificate for domain '$domain' renewed successfully."
        else
            error "Failed to renew SSL certificate for domain '$domain' using ACME.sh. check logs..."
        fi
    fi
}

get_cloudflare_ssl() {
    local domain="$1"    
    export CF_Key="$2"
    export CF_Email="$3"
    if sudo ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${domain} -d *.${domain} --log; then
        success "\n\n\t⭐ SSL certificate for domain '$domain' successfully obtained from Cloudflare."
        move_ssl_files_combined "$domain" "acme"
    else
        error "\n\tFailed to obtain SSL certificate for domain '$domain' from Cloudflare."
    fi
}

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

clear ; update_packages ; install_certbot ; install_acme ; clear

print "\n\n\t Welcome to ESSL"
print "\t\t v2.1.1 by @ErfJab\n\n"

while true; do
    print "-------------------------------------------------------"
    print "1) New Single Domain ssl (sub.domain.com)"
    print "2) New Wildcard ssl (*.domain.com)"
    print "3) New Multi-Domain ssl (sub.domain1.com, sub2.domain2.com ...)"
    print "4) Renewal ssl (update)" 
    print "5) Revoke ssl (delete)"
    print "0) Exit"
    input '\nPlease Select your option: ' 'option'
    clear

    if [ "$option" == "1" ]; then
        print "1) with acme & certbot (recommend)"
        print "2) with cloudflare api"
        input "\nplease enter your option number: " "select_option"
        clear
        if [[ "$select_option" =~ 1 ]]; then
            validate_domain
            validate_email
            clear
            get_single_ssl "$domain" "$email"
        elif [[ "$select_option" =~ 2 ]]; then
            validate_domain
            validate_email "cloudflare"
            validate_apikey
            clear
            get_cloudflare_ssl "$domain" "$email" "$api_key"
        else
            error "Invalid option."
        fi        

    elif [ "$option" == "2" ]; then
        print "1) with acme & certbot"
        print "2) with cloudflare api (recommend)"
        input "\nplease enter your option number: " "select_option"
        clear
        if [[ "$select_option" =~ 1 ]]; then
            validate_domain
            validate_email
            clear
            get_wildcard_ssl "$domain" "$email"
        elif [[ "$select_option" =~ 2 ]]; then
            validate_domain
            validate_email "cloudflare"
            validate_apikey
            clear
            get_cloudflare_ssl "$domain" "$email" "$api_key"
        else
            error "Invalid option. Please enter 1 or 2."
        fi   

    elif [ "$option" == "3" ]; then
        validate_domain
        validate_email
        clear
        get_multi_domain_ssl "$domain" "$email"

    elif [ "$option" == "4" ]; then
        validate_domain
        renew_ssl "$domain"

    elif [ "$option" == "5" ]; then
        validate_domain
        revoke_ssl "$domain"
    
    elif [ "$option" == "0" ]; then
        clear
        exit 1

    else
        error "Invalid input. Please select a valid option.\n\n"
    fi
done
