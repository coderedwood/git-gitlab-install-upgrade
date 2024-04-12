# Instructions on generating a self signed certificate using openssl

## Generation of a self-signed SSL certificate involves a simple 3-step procedure:

__STEP 1__: Create the server private key
```bash
openssl genrsa -out cert.key 2048
```
__STEP 2__: Create the certificate signing request (CSR) (will prompt for values for certain key subjects about your organization)
```bash
openssl req -new -key cert.key -out cert.csr
```
__STEP 3__: Sign the certificate using the private key and CSR
```bash
openssl x509 -req -days 3650 -in cert.csr -signkey cert.key -out cert.crt
```
## Generation of a self-signed SSL certificate involves a simple 1-step procedure
### In the 'subj' object in the command to follow, please note the following:
- 'C' is 2 character code for the country
- 'ST' is the country's State/Province
- 'L' is the city location
- 'O' is the name of your organisation
- 'OU' is the organizational unit
- 'CN' is the common name or the simplified host name
```bash
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
-subj "/C=GB/ST=London/L=London/O=Global Security/OU=R&D Department/CN=example.com" \
-keyout cert.key  -out cert.crt
```
### Further documentation can be viewed at
[OpenSSL Website x509](https://www.openssl.org/docs/man1.1.1/man1/x509.html)