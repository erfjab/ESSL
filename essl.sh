#!/bin/bash

clear
echo -e "\n\n\tWelcome to ESSL\n\t\tby @erfjab [gmail, telegram, github]\n\n"
echo "-------------------------"

validate_email() {
    if [[ ! "$1" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo -e "\e[91mInvalid email format. Please enter a valid email address.\e[0m"
        return 1
    fi
}

validate_domain() {
    if [[ ! "$1" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo -e "\e[91mInvalid domain format. Please enter a valid domain name.\e[0m"
        return 1
    fi
}

while true; do
    read -p 'Please enter your email: ' email
    if validate_email "$email"; then
        break
    fi
done

while true; do
    read -p 'Please enter your domain: ' domain
    if validate_domain "$domain"; then
        break
    fi
done

read -p 'Do you want SSL for marzban? (y/n): ' marzban

marzban=$(echo "$marzban" | tr '[:upper:]' '[:lower:]')

if [[ "$marzban" == 'y' || "$marzban" == 'yes' ]]; then
    address="/var/lib/marzban/certs/$domain"
    mkdir -p "$address"
else
    read -p 'Please enter your DR address: ' address
fi

echo -e "\nGet SSL with which tool?"
echo "1) certbot"
echo "2) acme.sh"
read -p 'Please select an option: ' option

while true; do
    case $option in
        1)
            sudo apt install snapd || { echo "Error installing snapd"; exit 1; }
            
            sudo apt remove certbot || { echo "Error removing old certbot"; exit 1; }

            sudo snap install --classic certbot || { echo "Error installing certbot via snap"; exit 1; }

            sudo certbot certonly --standalone -d "$domain" || { echo "Error getting SSL certificate"; exit 1; }

            sudo mkdir -p "$address"
            sudo mv /etc/letsencrypt/live/"$domain"/fullchain.pem "$address/fullchain.pem" || { echo "Error copying certificate files"; exit 1; }
            sudo mv /etc/letsencrypt/live/"$domain"/privkey.pem "$address/privkey.pem" || { echo "Error copying certificate files"; exit 1; }
            break
            ;;
        2)

            curl https://get.acme.sh | sh -s email="$email" || { echo "Error installing acme.sh"; exit 1; }

            export DOMAIN="$domain"
            mkdir -p "$address"
            ~/.acme.sh/acme.sh \
                --issue --force --standalone -d "$DOMAIN" \
                --fullchain-file "$address/$DOMAIN.cer" \
                --key-file "$address/$DOMAIN.cer.key" || { echo "Error getting SSL certificate"; exit 1; }
            break
            ;;
        *)
            echo -e "\e[91mInvalid option selected.\e[0m"
            read -p 'Please select again an option: ' option
            ;;
    esac
done

echo -e "\e[92mIf you found this script helpful, please consider starring the ESSL on GitHub.\e[0m\n\n"
