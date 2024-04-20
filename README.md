# What is ESSL?
ESSL (Easy SSL) is a user-friendly script designed to streamline the process of obtaining SSL certificates through various methods. It simplifies the procedure, sparing users from confusing and unnecessary commands. Moreover, ESSL facilitates the segregation of panel domain and users subscription domain within Marzban(a Xray control panel) Currently, ESSL supports the following SSL acquisition options:
- certbot
- acme

> [!IMPORTANT]
> More options will be added soon. 🔥

# How to Use?
Follow these steps to utilize ESSL effectively:

1. Execute the following command in your terminal:
```bash
sudo bash -c "$(curl -sL https://github.com/erfjab/ESSL/raw/main/essl.sh)"
```

2. Enter the required information as prompted:

- **Email**: Provide your email address, which will be utilized for SSL usage.
- **Domain**: Specify the domain for which you wish to obtain SSL.
- **multi-domain**: If you want multi-domain SSL, enter 'y' and provide your additional domain. Otherwise, enter 'n'. ([source](https://github.com/Gozargah/Marzban/discussions/684))
- **Address**: If you are using Marzban, the SSL directory is default. Input 'y'. Otherwise, if you prefer a custom directory, input 'n' and specify your desired directory.
- **Options**: Select the appropriate option by entering its corresponding number.

Once completed, the SSL script will acquire the SSL certificate for your domain and place it in the specified folder. Should you encounter any issues or have inquiries, feel free to communicate them in the issue section. Additionally, you can subscribe to my Telegram channel [@ErfJabs](https://t.me/ErfJabs) to receive notifications regarding script updates and news.

**Don't Forget ⭐, good luck.**
