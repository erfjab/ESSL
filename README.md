![example essl](essl.mp4)

<p align="center">
  <a href="./README.md">
	English
	</a>
	|
	<a href="./README_fa.md">
	فارسی
	</a>
</p>

# What is ESSL?
ESSL (Easy SSL) is a user-friendly script designed to streamline the process of obtaining SSL certificates through various methods. It simplifies the procedure, sparing users from confusing and unnecessary commands. just copy and paste one line so that everything is done automatically.

### Future's:
- Single domain ssl (sub.domain.com)
- Wildcard domain ssl (*.domain.com)
- Multi-domain ssl (sub1.doamin1.com sub2.domain2.com)
- Renewal ssl (update)
- Revoke ssl (delete)
- Automatic/Custom patch (support all panel's directory)

> [!IMPORTANT]
> In the current version, only `certbot` is used.


## How to Use?

just copy/paste and enjoy : 

```bash
sudo bash -c "$(curl -sL https://github.com/erfjab/ESSL/raw/main/essl.sh)"
```
<details>

<summary>Single Domain</summary>
	
In single domain after set DNS you only need :
- `domain` (e.g: sub.doamin.com)
- `email`

After receiving ssl, it will show you three path, the first one is for the desired path, the second one is for the border panel path and the third one is for the path of other panels. You received a certificate so easily and easily.
</details>


<details>

<summary>Wildcard Domain</summary>
	
In wildcard domain after set DNS you only need :
- `domain` (e.g: domain.com)
- `email`

Now it gives you a name and text value, which asks you to set them in text dns format, after a few moments, click set enter.

After receiving ssl, it will show you three path, the first one is for the desired path, the second one is for the border panel path and the third one is for the path of other panels. You received a certificate so easily and easily.
</details>


<details>

<summary>Multi-Domain</summary>
	
In Multi domain after set DNS you only need :
- `domain's` (in a line with a space e.g: sub1.domain1.com sub2.domain2.com...)
- `email`

After receiving ssl, it will show you three path, the first one is for the desired path, the second one is for the border panel path and the third one is for the path of other panels. You received a certificate so easily and easily.
</details>

<details>

<summary>Renewal</summary>
	
In renewal you only need :
- `domain` (e.g: *.domain.com (wildcard) sub.domain.com (single))

If it needs to be extended, it will be extended, otherwise it will say that it is not needed yet.
</details>


<details>

<summary>Revoke</summary>
	
In Revoke fi you only need :
- `fullchain.pem path` (e.g: /etc/letsencrypt/live/essl.sweter.top/fullchain.pem)

In revoke, it will first show you the list of domains so you can choose the desired domain and copy/paste the exact address of the domain to be revoked.
</details>

## Support project 

**We don't need financial support, only Star (⭐) is enough, thank you.**
