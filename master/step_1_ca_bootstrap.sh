#!/usr/bin/env bash
 
###########################################################################################
#                                                                                         #
#       STEP 1 OF THE WHOLE PROCESS. RUN THIS SCRIPT BEFORE ANYTHING.                     #
#                                                                                         #
# THIS SCRIPT WILL GENERATE KUBERNETES CA CERTIFICATE AND PRIVAKEY KEY ON EXECUTING NODE. #
#                                                                                         #
###########################################################################################
 
set -xe
 
####### variables ############
 
CA_DIR=${CA_DIR:-~/kubernetes_ca}               ##### WILL USE PROVIDED CA_DIR IF SET
CA_KEY_FILENAME="kubernetes_ca"                 ##### YOU MAY CHANGE THE FILE NAMES IF YOU WANT TO
CA_CERT_FILENAME="kubernetes_ca"                ##### YOU MAY CHANGE THE FILE NAMES IF YOU WANT TO
CA_CSR_CONFIG_FILENAME="kubernetes_ca_csr"      ##### YOU MAY CHANGE THE FILE NAMES IF YOU WANT TO
 
##############################
 
 
mkdir -p $CA_DIR
cd $CA_DIR
 
 
 
###### generate ca key and cert #######
 
openssl genrsa -out $CA_KEY_FILENAME.key 2048
echo -e "Generate CA Private key file -> done. "
 
tee $CA_CSR_CONFIG_FILENAME.conf <<-EOF
 
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
 
[ dn ]
CN=kubernetes
 
[ v3_ca ]
basicConstraints        = critical,CA:TRUE
keyUsage                = critical, cRLSign, keyCertSign
subjectKeyIdentifier    = hash
 
EOF
 
openssl req -x509 -new -nodes -key $CA_KEY_FILENAME.key  -days 10000 -out $CA_CERT_FILENAME.crt -extensions v3_ca -config $CA_CSR_CONFIG_FILENAME.conf
echo -e "Generate CA Certificate file -> done. "
 
echo -e "Printing CA Certificate file. "
openssl x509 -text -noout -in $CA_CERT_FILENAME.crt
 
PRINT_CA_CERT_SHA=$(openssl x509 -pubkey -in $CA_KEY_FILENAME.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
echo -e "The CA Certificate SHA is : $PRINT_CA_CERT_SHA"
 
#######################################
