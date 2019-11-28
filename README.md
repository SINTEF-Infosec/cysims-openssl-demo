# CySims PKI DEMO

This demo requires openssl with built-in support for Elliptic Curves.

## Running the demo

If you don't have it (on MacOS X for instance), you can use a docker image instead.

You can start a debian docker image with the following command:

```
docker run -t -v /path/to/this/repo:/mnt/volumes -i debian /bin/bash
```

Then install the required dependencies:
```
# To be run inside the docker container
apt update && apt upgrade && apt install git
```

Then you can launch the script and access the results from your host machine:
```
cd /mnt/volumes && ./run_demo.sh
```

## Results

The demo results in a `ca` directory containing all the certificates and artefacts of the PKI.

```
*** CySiMS Certificates Generation - Demo ***
STEP 0: Generating all directories
STEP 1: Root CA Generation
[*] Configuring the Root CA...done
[*] Generating the Root CA keys...done
[*] Self-signing the Root CA certificate...done
STEP 2: Intermediate CA Generation
[*] Configuring Intermediate CA 0...done
[*] Generating Intermediate CA 0 keys...done
[*] Generating Intermediate CA 0 CSR...done
[*] Signing Intermediate CA 0 CSR...done
[*] Verifying Certificate for Intermediate CA 0: certs/int0.norwegianmaritimeauthority.crt.pem: OK
[*] Creating Certificates Chain for Intermediate CA 0...done
[*] Configuring Intermediate CA 1...done
[*] Generating Intermediate CA 1 keys...done
[*] Generating Intermediate CA 1 CSR...done
[*] Signing Intermediate CA 1 CSR...done
[*] Verifying Certificate for Intermediate CA 1: certs/int1.norwegianmaritimeauthority.crt.pem: OK
[*] Creating Certificates Chain for Intermediate CA 1...done
STEP 3: Ships Certificates Generation
[*] Generating certificate for Ship 0 using Intermediate CA 1
 - [*] Generating key for Ship 0...done
 - [*] Generating CSR for Ship 0...done
 - [*] Signing Ship 0 CSR using Intermediate CA 1...done
[*] Verifying Certificate for Ship 0: certs/ship0.int1.norwegianmaritimeauthority.crt.pem: OK
[*] Generating certificate for Ship 1 using Intermediate CA 0
 - [*] Generating key for Ship 1...done
 - [*] Generating CSR for Ship 1...done
 - [*] Signing Ship 1 CSR using Intermediate CA 0...done
[*] Verifying Certificate for Ship 1: certs/ship1.int0.norwegianmaritimeauthority.crt.pem: OK
[*] Generating certificate for Ship 2 using Intermediate CA 1
 - [*] Generating key for Ship 2...done
 - [*] Generating CSR for Ship 2...done
 - [*] Signing Ship 2 CSR using Intermediate CA 1...done
[*] Verifying Certificate for Ship 2: certs/ship2.int1.norwegianmaritimeauthority.crt.pem: OK
[*] Generating certificate for Ship 3 using Intermediate CA 1
 - [*] Generating key for Ship 3...done
 - [*] Generating CSR for Ship 3...done
 - [*] Signing Ship 3 CSR using Intermediate CA 1...done
[*] Verifying Certificate for Ship 3: certs/ship3.int1.norwegianmaritimeauthority.crt.pem: OK
STEP 4: Shore Stations Certificates Generation
[*] Generating certificate for Shore Station 0 using Intermediate CA 1
 - [*] Generating key for Shore Station 0...done
 - [*] Generating CSR for Shore Station 0...done
 - [*] Signing Shore Station 0 CSR using Intermediate CA 1...done
[*] Verifying Certificate for Shore Station 0: certs/shore_station0.int1.norwegianmaritimeauthority.crt.pem: OK
[*] Generating certificate for Shore Station 1 using Intermediate CA 0
 - [*] Generating key for Shore Station 1...done
 - [*] Generating CSR for Shore Station 1...done
 - [*] Signing Shore Station 1 CSR using Intermediate CA 0...done
[*] Verifying Certificate for Shore Station 1: certs/shore_station1.int0.norwegianmaritimeauthority.crt.pem: OK
[*] Generating certificate for Shore Station 2 using Intermediate CA 0
 - [*] Generating key for Shore Station 2...done
 - [*] Generating CSR for Shore Station 2...done
 - [*] Signing Shore Station 2 CSR using Intermediate CA 0...done
[*] Verifying Certificate for Shore Station 2: certs/shore_station2.int0.norwegianmaritimeauthority.crt.pem: OK
[*] Generating certificate for Shore Station 3 using Intermediate CA 1
 - [*] Generating key for Shore Station 3...done
 - [*] Generating CSR for Shore Station 3...done
 - [*] Signing Shore Station 3 CSR using Intermediate CA 1...done
[*] Verifying Certificate for Shore Station 3: certs/shore_station3.int1.norwegianmaritimeauthority.crt.pem: OK
*** DONE ***
```

## Using the artefacts

### Signing data during Ship to Ship communication

We illustrate how data can be signed by SHIP0 before being sent to SHIP1 and how SHIP1 can verify the signature of the data. Here the certificate of SHIP0 has been issued by Intermediate CA 1.

ON SHIP0:
```
# Creating the content to send
$ echo "Hey Ship one, ship zero speaking, this is my position: 63.490996, 10.444875" > data_file.txt

# Signing it using SHIP 0 private key
$ openssl dgst -sha256 \
    -sign ca/ships/ship0/private/ship0.norwegianmaritimeauthority.key.pem \
    -out data_file.txt.sha256 data_file.txt
```

Both files are sent to SHIP1.

ON SHIP1:
```
# Extracting SHIP 0 public key from its certificate and verifying the signature
$ openssl dgst -sha256 \
  -verify <(openssl x509 -in ca/ships/ship0/certs/ship0.int1.norwegianmaritimeauthority.crt.pem -pubkey -noout) \
  -signature data_file.txt.sha256 data_file.txt
Verified OK
```

The result if the data has not been modified should then be: `Verified OK`

If `data_file.txt` is modified, for instance if we change the coordinates to: "60.490996, 10.444875". Then the same command results in: `Verification Failure`.
