#!/usr/bin/env bash
 
###########################################################################################################################
#                                                                                                                         #
#       A SUBSTEP OF STEP 2 SCRIPT. DO NOT INVOKE EXPLICITLY. THIS GETS INVOKED BY STEP 2 SCRIPT INTERNALLY.              #
#                                                                                                                         #
# THIS SCRIPT WILL GENERATE PAIR OF PRIVATE KEYS AND CERTIFICATE SIGNING REQUESTS (CSR) FOR KUBERNETES ON EXECUTING NODE. #
#                                                                                                                         #
###########################################################################################################################
 
set -xe
 
########################## VARIABLES ######################
 
HOSTNAME=$(hostname)
 
AGENT_CSR_HOLDER_DIRECTORY=${AGENT_CSR_HOLDER_DIRECTORY:-~/kubernetes-certs}                            ###### NEEDS TO BE SAME AS "AGENT_TEMP_CSR_HOLDER_DIR" VARIABLE FROM STEP 2 SCRIPT.
KUBERNETES_CONTROLLER_AGENT_HOSTNAME=${KUBERNETES_CONTROLLER_AGENT_HOSTNAME:-puppet-agent-01}	        ###### NEEDS TO BE THE FIRST HOSTNAME OF YOUR kubernetes::etcd_initial_cluster VARIABLE IN GENERATED REDHAT.YAML FILE
                                                                                                        ###### OR THE FIRST HOSTNAME OF YOUR step_3_generate_redhat.sh
KUBERNETES_CONTROLLER_ADDRESS=$(grep -F "$KUBERNETES_CONTROLLER_AGENT_HOSTNAME" "/etc/hosts" | awk '{ print $1}')

CNI_APISERVER_CONNECTION_ADDRESS=10.96.0.1		        ##### NEEDS TO BE FIRST ADDRESS FROM service_cidr PARAMETER FROM PUPPETLABS/KUBERNETES MODULE init.pp FILE. USED BETWEEN CILIUM POD AND APISERVER COMMUNICATION.
 
COMMON_CLIENT_FILENAME="common-client"
FRONT_PROXY_CLIENT_FILENAME="front-proxy-client"
API_SERVER_KUBELET_CLIENT_FILENAME="apiserver-kubelet-client"
API_SERVER_FILENAME="apiserver"

##############################################################
 
 
################### generate common client for admin.conf ###################
 
mkdir -p $AGENT_CSR_HOLDER_DIRECTORY
chown -v ${SUDO_USER:-$(whoami)}: $AGENT_CSR_HOLDER_DIRECTORY
tee $AGENT_CSR_HOLDER_DIRECTORY/$COMMON_CLIENT_FILENAME.conf <<-EOF
[req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn
 
[ dn ]
O=system:masters
CN=kubernetes-admin
 
[ req_ext ]
subjectAltName = @alt_names
 
[ alt_names ]
DNS.1 = kubernetes-admin
 
[ v3_ext ]
keyUsage                = critical, digitalSignature, keyEncipherment
extendedKeyUsage        = clientAuth
authorityKeyIdentifier  = keyid
EOF
 
openssl genrsa -out $AGENT_CSR_HOLDER_DIRECTORY/$COMMON_CLIENT_FILENAME.key 2048
echo -e "$HOSTNAME: \tGenerate Common-Client Private key file -> done. "
 
openssl req -new -key $AGENT_CSR_HOLDER_DIRECTORY/$COMMON_CLIENT_FILENAME.key -out $AGENT_CSR_HOLDER_DIRECTORY/$COMMON_CLIENT_FILENAME.csr -config $AGENT_CSR_HOLDER_DIRECTORY/$COMMON_CLIENT_FILENAME.conf
echo -e "$HOSTNAME: \tGenerate Common-Client CSR file -> done. "
 
####################################################################
 
 
################### front proxy client ##################
 
tee $AGENT_CSR_HOLDER_DIRECTORY/$FRONT_PROXY_CLIENT_FILENAME.conf <<-EOF
 
[req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn
 
[ dn ]
CN=front-proxy-client
 
[ req_ext ]
subjectAltName = @alt_names
 
[ alt_names ]
DNS.1 = front-proxy-client
 
[ v3_ext ]
keyUsage                = critical, digitalSignature, keyEncipherment
extendedKeyUsage        = clientAuth
authorityKeyIdentifier  = keyid
 
EOF
 
openssl genrsa -out $AGENT_CSR_HOLDER_DIRECTORY/$FRONT_PROXY_CLIENT_FILENAME.key 2048
echo -e "$HOSTNAME: \tGenerate Front proxy Client Private key file -> done. "
 
openssl req -new -key $AGENT_CSR_HOLDER_DIRECTORY/$FRONT_PROXY_CLIENT_FILENAME.key -out $AGENT_CSR_HOLDER_DIRECTORY/$FRONT_PROXY_CLIENT_FILENAME.csr -config $AGENT_CSR_HOLDER_DIRECTORY/$FRONT_PROXY_CLIENT_FILENAME.conf
echo -e "$HOSTNAME: \tGenerate Front proxy Client CSR file -> done. "

#############################################################################
 
 
####################### apiserver kubelet client ############################
 
tee $AGENT_CSR_HOLDER_DIRECTORY/$API_SERVER_KUBELET_CLIENT_FILENAME.conf <<-EOF
 
[req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
 
[ dn ]
O=system:masters
CN=kube-apiserver-kubelet-client
 
[ v3_ext ]
keyUsage                = critical, digitalSignature, keyEncipherment
extendedKeyUsage        = clientAuth
authorityKeyIdentifier  = keyid
 
EOF
 
openssl genrsa -out $AGENT_CSR_HOLDER_DIRECTORY/$API_SERVER_KUBELET_CLIENT_FILENAME.key 2048
echo -e "$HOSTNAME: \tGenerate API server kubelete Client Private key file -> done. "
 
openssl req -new -key $AGENT_CSR_HOLDER_DIRECTORY/$API_SERVER_KUBELET_CLIENT_FILENAME.key -out $AGENT_CSR_HOLDER_DIRECTORY/$API_SERVER_KUBELET_CLIENT_FILENAME.csr -config $AGENT_CSR_HOLDER_DIRECTORY/$API_SERVER_KUBELET_CLIENT_FILENAME.conf
echo -e "$HOSTNAME: \tGenerate API server kubelet Client CSR file -> done. "
 
 
##################################################################################
 
 
############################### apiserver #######################################
 
tee $AGENT_CSR_HOLDER_DIRECTORY/$API_SERVER_FILENAME.conf <<-EOF
 
 
[req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn
 
[ dn ]
CN=kube-apiserver
 
[ req_ext ]
subjectAltName = @alt_names
 
[ alt_names ]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster
DNS.5 = kubernetes.default.svc.cluster.local
DNS.6 = $(hostname)
IP.1 = $(hostname -i)
IP.2 = ${KUBERNETES_CONTROLLER_ADDRESS:-127.0.0.1}
IP.3 = ${CNI_APISERVER_CONNECTION_ADDRESS:-10.96.0.1}
 
[ v3_ext ]
keyUsage                = critical, digitalSignature, keyEncipherment
extendedKeyUsage        = serverAuth
authorityKeyIdentifier  = keyid
subjectAltName          = @alt_names
 
EOF
 
openssl genrsa -out $AGENT_CSR_HOLDER_DIRECTORY/$API_SERVER_FILENAME.key 2048
echo -e "$HOSTNAME: \tGenerate API server Private key file -> done. "
 
openssl req -new -key $AGENT_CSR_HOLDER_DIRECTORY/$API_SERVER_FILENAME.key -out $AGENT_CSR_HOLDER_DIRECTORY/$API_SERVER_FILENAME.csr -config $AGENT_CSR_HOLDER_DIRECTORY/$API_SERVER_FILENAME.conf
echo -e "$HOSTNAME: \tGenerate API server CSR file -> done. "
 
##################################################################################
