#!/bin/bash

clear
echo -e "\n\n\t\e[92mWelcome to ESSL\n\t\tby @erfjab [gmail, telegram, github]\e[0m\n\n"
echo -e "\e[92m-------------------------\e[0m"

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

read -p 'Do you want multi-domain SSL? (y/n): ' has_multi_domain
has_multi_domain=$(echo "$has_multi_domain" | tr '[:upper:]' '[:lower:]')

if [[ "$has_multi_domain" == 'y' || "$has_multi_domain" == 'yes' ]]; then
    while true; do
        read -p 'Please enter your second domain: ' domain2 && \
        if validate_domain "$domain2"; then
            apt-get install -y curl cron socat
            curl https://get.acme.sh | sh -s email="$email" || { echo "Error installing acme.sh"; exit 1; }
            ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt --issue --force --standalone \
            -d $domain -d $domain2 || { echo "Error issuing SSL certificate"; exit 1; }
            ~/.acme.sh/acme.sh --installcert -d $domain \
            --key-file $address/key.pem \
            --fullchain-file $address/fullchain.pem || { echo "Error installing SSL certificate"; exit 1; }
            break
        fi
    done
else
    echo -e "\nGet SSL with which tool?\n"
    echo "1) certbot"
    echo -e "2) acme.sh\n" && \
    read -p 'Please select an option: ' option && \

    while true; do
        case $option in
            1)
                sudo apt install snapd -y || { echo "Error installing snapd"; exit 1; }
                
                sudo apt remove certbot -y || { echo "Error removing old certbot"; exit 1; }

                sudo snap install --classic certbot -y || { echo "Error installing certbot via snap"; exit 1; }

                sudo certbot certonly --standalone -d "$domain" -y || { echo "Error getting SSL certificate"; exit 1; }

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
fi


echo -e "\n\n\e[92mYour ssl in here : $address\n\t\tDon't forget ⭐, good luck.\e[0m\n\n"
