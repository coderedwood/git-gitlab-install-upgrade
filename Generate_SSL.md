# Instructions on generating a self signed certificate using openssl

# 1. Generate a Private Certificate Authority
- Generate the CA key using desired encryption algorithm (example uses aes 256 bit with a 4096 bit rsa)
```bash
openssl genrsa -aes256 -out ca-cert.key 4096
```
- Enter a passphrase

- Generate the CA cert via a certificate sign request
```bash
openssl req -new -x509 -sha256 -days 3650 -key ca-cert.key -out ca-cert.crt
```
- Enter the information for your CA(can be anything)

- Verify thah the cert has the Certificate Authority as true 'CA:TRUE'
```bash
openssl x509 -in ca-cert.crt -text
```

### In the '-subj' object in the commands to follow, please note the following:
- 'C' is 2 character code for the country
- 'ST' is the country's State/Province
- 'L' is the city location
- 'O' is the name of your organisation
- 'OU' is the organizational unit
- 'CN' is the common name or the simplified host name

## One step version of the above CA cert (aes not supported in private key generatin in the request method, elliptic curve used in example)
```bash
openssl req -new -newkey rsa:4096 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
-days 3650 -x509 -sha256 \
-subj "/C=GB/ST=London/L=London/O=Global Security/OU=R&D Department/CN=example.com" \
-keyout ca-cert.key -out ca-cert.crt
```

- Enter a passphrase to complete the generation

# 2. Generation of a self-signed SSL certificate using the CA:

__STEP 1__: Create the server private key
```bash
openssl genrsa -out cert.key 4096
```
__STEP 2__: Create the certificate signing request (CSR) (will prompt for values for certain key subjects about your organization)
```bash
openssl req -new -sha256 -subj "/CN=<<servername>>" -key cert.key -out cert.csr
```
__STEP 3__: Create a config file for the alternate names for the node for the cert
```bash
echo "subjectAltName=DNS:<<DNSname>>,IP:<<serverip>>" >> extfile.cnf
```

__STEP 4__: Sign the certificate using the private key and CSR
```bash
openssl x509 -req -days 3650 -in cert.csr -CA ca-cert.crt -CAkey ca-cert.key --extfile extfile.cnf -out cert.crt -CAcreateserial
```
- Enter passphrase for the CA key you created to complete generating the cert

__STEP 5__: Create the full certificate chain by chaining the self-signed cert with the CA cert into one file in the order listed.
```bash
echo cert.crt > ssl-cert.crt
```
```bash
echo ca-cert.crt > ssl-cert.crt
```

### Chained in one step we have
```bash
openssl genrsa -out cert.key 4096 && \
openssl req -new -sha256 -subj "/CN=<<servername>>" -key cert.key -out cert.csr && \
echo "subjectAltName=DNS:<<servername>>,IP:<<serverIP>>" >> extfile.cnf && \
openssl x509 -req -days 3650 -in cert.csr -CA ca-cert.crt -CAkey ca-cert.key --extfile \
extfile.cnf -out cert.crt -CAcreateserial && echo cert.crt > ssl-cert.crt && \
echo ca-cert.crt > ssl-cert.crt
```

## Important final outputs from the above section are:
- ca-cert.key (this can be used to sign other self-signed certificates for additiona server nodes)
- ca-cert.crt (This should be added to the Trusted Root Certificates of the client nodes to validate any issued self-signed certs from your private CA)
- cert.key (to be paired with ssl-cert on server node)
- ssl-cert.crt (self-signed certificate to be paired with cert.key, issued on node request for ssl validation)

# Usage approach
- Generate CA root cert in Main step 1. Only need to do this once.
- Generate individual ssl certificates for the different nodes. Use Main step 2 repeatedly for signing with the CA root.

### Further documentation can be viewed at
[OpenSSL Website x509](https://www.openssl.org/docs/man1.1.1/man1/x509.html)