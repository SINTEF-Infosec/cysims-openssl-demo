#! /bin/bash
#
# Script: run_demo.sh
# Date: 28/11/2019
# Author: SINTEF Digital
#
# Description:
# This script aims to demonstrate how to generate a PKI for the CySiMS project.
# /!\ This is a demo.

# Defining several variables to control the demo
# Where to generate the certificates
BASE_DIR=/mnt/volumes
CA_DIR=$BASE_DIR/ca

# Number of intermediate CA
NB_INT_CA=2
# Number of ships
NB_SHIP=4
# Number of shore stations
NB_SHORE_STATION=4

ORG_NAME="NorwegianMaritimeAuthority"
AUTH_NAME="norwegianmaritimeauthority"

issued_ships=0
issued_shore_station=0

# Generates the directories for all entities
function gen_directories() {
  # Remove any previous directory with the same name
  rm -rf $CA_DIR

  # General directory that will contain all the certificates
  mkdir $CA_DIR && cd $CA_DIR

  # Directories for the different CAs and entities
  mkdir root intermediate ships shore_stations

  # Directories for the root CA
  mkdir -p root/{private,crl,certs,newcerts,requests}

  # Directories for the intermediate CA
  for (( c=0; c<$NB_INT_CA; c++ ))
  do
     mkdir -p intermediate/intermediate$c/{private,csr,crl,certs,newcerts,requests}
  done

  # Directories for the ships
  for (( c=0; c<$NB_SHIP; c++ ))
  do
     mkdir -p ships/ship$c/{private,csr,certs}
  done

  # Directories for the shore stations
  for (( c=0; c<$NB_SHORE_STATION; c++ ))
  do
     mkdir -p shore_stations/shore_station$c/{private,csr,certs}
  done
}


# Generates the Root CA artifacts
function gen_root_ca() {
  cd $CA_DIR/root

  echo -n "[*] Configuring the Root CA..."
  sed -e "s/\${DOMAIN}/$AUTH_NAME/" \
      -e 's|\${DIR}|'$CA_DIR/root'|' \
      $BASE_DIR/conf/openssl_root.cnf.template > openssl_root.cnf
  # database where the issued certificates will be registered
  touch database.txt
  # serial number for the issued certificate
  echo "0001" > serial
  # Certification Revocation List
  touch crlnumber
  echo "done"

  echo -n "[*] Generating the Root CA keys..."
  openssl genpkey -algorithm EC \
    -pkeyopt ec_paramgen_curve:P-384 \
    -out private/ca.$AUTH_NAME.key.pem
  echo "done"

  echo -n "[*] Self-signing the Root CA certificate..."
  openssl req -config openssl_root.cnf -new \
    -x509 \
    -sha256 \
    -extensions v3_ca \
    -key private/ca.$AUTH_NAME.key.pem \
    -out certs/ca.$AUTH_NAME.crt.pem \
    -days 3650 \
    -subj "/C=NO/O=$ORG_NAME/CN=CysimsRootCA"
  echo "done"
}


# Generate the Intermediate CA artifacts
# ARG1: id of the CA (0..NB_INT_CA)
function gen_intermediate_ca() {
  num=$1

  cd $CA_DIR/intermediate/intermediate$num

  echo -n "[*] Configuring Intermediate CA $num..."
  sed -e "s/\${DOMAIN}/$AUTH_NAME/" \
      -e 's|\${DIR}|'$CA_DIR/intermediate/intermediate$num'|' \
      -e "s/\${NUM}/$num/" \
      $BASE_DIR/conf/openssl_intermediate.cnf.template > openssl_intermediate.cnf
  # database where the issued certificates will be registered
  touch database.txt
  # serial number for the issued certificate
  echo "10"$c"000" > serial
  # Certification Revocation List
  touch crlnumber
  echo "done"

  echo -n "[*] Generating Intermediate CA $num keys..."
  openssl genpkey -algorithm EC \
    -pkeyopt ec_paramgen_curve:P-384 \
    -out private/int$num.$AUTH_NAME.key.pem
  echo "done"

  echo -n "[*] Generating Intermediate CA $num CSR..."
  openssl req -new \
    -key private/int$num.$AUTH_NAME.key.pem \
    -out csr/int$num.$AUTH_NAME.csr \
    -subj "/C=NO/O=$ORG_NAME/CN=CysimsIntermediateCA-$num"
  echo "done"

  echo -n "[*] Signing Intermediate CA $num CSR..."
  yes | openssl ca \
    -config $CA_DIR/root/openssl_root.cnf \
    -extensions v3_intermediate_ca \
    -days 3650 \
    -notext \
    -in csr/int$num.$AUTH_NAME.csr \
    -out certs/int$num.$AUTH_NAME.crt.pem 2>/dev/null
  echo "done"

  echo -n "[*] Verifying Certificate for Intermediate CA $num: "
  openssl verify \
    -CAfile $CA_DIR/root/certs/ca.$AUTH_NAME.crt.pem \
    certs/int$num.$AUTH_NAME.crt.pem
  if [ $? -ne 0 ]; then
    echo "[x] Certificate verification for Intermediate CA $num failed!"
    exit 1;
  fi

  echo -n "[*] Creating Certificates Chain for Intermediate CA $num..."
  cat $CA_DIR/root/certs/ca.$AUTH_NAME.crt.pem \
    $CA_DIR/intermediate/intermediate$num/certs/int$num.$AUTH_NAME.crt.pem \
    > $CA_DIR/intermediate/intermediate$num/certs/chain.int$num.$AUTH_NAME.crt.pem
  echo "done"
}


# Generate the Ships artifacts (key, csr, certificate)
# ARG1: id of the ship (0..NB_SHIP)
# ARG2: id of the CA (0..NB_INT_CA) that is gonna be used
# ARG3: common name to use for the ship
function gen_ship_cert() {
  num=$1
  int_ca=$2
  ship_cn=$3

  cd $CA_DIR/ships/ship$num

  echo "[*] Generating certificate for Ship $num using Intermediate CA $int_ca"

  echo -n " - [*] Generating key for Ship $num..."
  openssl genpkey -algorithm EC \
    -pkeyopt ec_paramgen_curve:P-256 \
    -out private/ship$num.$AUTH_NAME.key.pem
  echo "done"

  echo -n " - [*] Generating CSR for Ship $num..."
  openssl req -new \
    -key private/ship$num.$AUTH_NAME.key.pem \
    -out csr/ship$num.int$int_ca.$AUTH_NAME.csr.pem \
    -subj "/CN=$ship_cn/C=NO/O=$ORG_NAME/OU=TrondheimUnit"
  echo "done"

  echo -n " - [*] Signing Ship $num CSR using Intermediate CA $int_ca..."
  yes | openssl ca \
    -config $CA_DIR/intermediate/intermediate$int_ca/openssl_intermediate.cnf \
    -extensions ship_cert \
    -days 1095 \
    -notext \
    -md sha256 \
    -in csr/ship$num.int$int_ca.$AUTH_NAME.csr.pem \
    -out certs/ship$num.int$int_ca.$AUTH_NAME.crt.pem 2>/dev/null
  echo "done"

  echo -n "[*] Verifying Certificate for Ship $num: "
  openssl verify \
    -CAfile $CA_DIR/intermediate/intermediate$int_ca/certs/chain.int$int_ca.$AUTH_NAME.crt.pem \
    certs/ship$num.int$int_ca.$AUTH_NAME.crt.pem
  if [ $? -ne 0 ]; then
    echo "[x] Certificate verification for Ship $num failed!"
    exit 1;
  fi

  issued_ships=$(($issued_ships + 1))
}


# Generate the Shore Stations artifacts (key, csr, certificate)
# ARG1: id of the shore station (0..NB_SHORE_STATION)
# ARG2: id of the CA (0..NB_INT_CA) that is gonna be used
function gen_shore_station_cert() {
  num=$1
  int_ca=$2
  shore_station_id=`printf %08d $(($issued_shore_stations))`

  cd $CA_DIR/shore_stations/shore_station$num

  echo "[*] Generating certificate for Shore Station $num using Intermediate CA $int_ca"

  echo -n " - [*] Generating key for Shore Station $num..."
  openssl genpkey -algorithm EC \
    -pkeyopt ec_paramgen_curve:P-256 \
    -out private/shore_station$num.$AUTH_NAME.key.pem
  echo "done"

  echo -n " - [*] Generating CSR for Shore Station $num..."
  openssl req -new \
    -key private/shore_station$num.$AUTH_NAME.key.pem \
    -out csr/shore_station$num.int$int_ca.$AUTH_NAME.csr.pem \
    -subj "/CN=SHORE-STATION-$shore_station_id/C=NO/O=$ORG_NAME/OU=TrondheimUnit/"
  echo "done"

  echo -n " - [*] Signing Shore Station $num CSR using Intermediate CA $int_ca..."
  yes | openssl ca \
    -config $CA_DIR/intermediate/intermediate$int_ca/openssl_intermediate.cnf \
    -extensions shore_station_cert \
    -days 1095 \
    -notext \
    -md sha256 \
    -in csr/shore_station$num.int$int_ca.$AUTH_NAME.csr.pem \
    -out certs/shore_station$num.int$int_ca.$AUTH_NAME.crt.pem 2>/dev/null
  echo "done"

  echo -n "[*] Verifying Certificate for Shore Station $num: "
  openssl verify \
    -CAfile $CA_DIR/intermediate/intermediate$int_ca/certs/chain.int$int_ca.$AUTH_NAME.crt.pem \
    certs/shore_station$num.int$int_ca.$AUTH_NAME.crt.pem
  if [ $? -ne 0 ]; then
    echo "[x] Certificate verification for Shore Station $num failed!"
    exit 1;
  fi

  issued_shore_stations=$(($issued_shore_stations + 1))
}


################################################################################
###                              MAIN STEPS                                  ###
################################################################################

echo "*** CySiMS Certificates Generation - Demo ***"
cd $BASE_DIR

echo "STEP 0: Generating all directories"
gen_directories

echo "STEP 1: Root CA Generation"
gen_root_ca

echo "STEP 2: Intermediate CA Generation"
for (( c=0; c<$NB_INT_CA; c++ ))
do
  gen_intermediate_ca $c
done

echo "STEP 3: Ships Certificates Generation"
for (( c=0; c<$NB_SHIP; c++ ))
do
  # Choosing a Intermediate CA randomly
  int_ca=`shuf -i 0-$(($NB_INT_CA - 1)) -n 1`
  ship_nb=`printf %08d $((c))`
  gen_ship_cert $c $int_ca "258$int_ca$ship_nb"
done

echo "STEP 4: Shore Stations Certificates Generation"
for (( c=0; c<$NB_SHORE_STATION; c++ ))
do
  # Choosing a Intermediate CA randomly
  int_ca=`shuf -i 0-$(($NB_INT_CA - 1)) -n 1`
  gen_shore_station_cert $c $int_ca
done

echo "*** DONE ***"
