#!/usr/bin/env bash
 
####################################################################################################################
#                                                                                                                  #
#   STEP 2 OF THE WHOLE PROCESS. RUN THIS SCRIPT WITH SUDO PRIVILEDGES ON MASTER.     	                           #
#                                                                                                                  #
# THIS SCRIPT WILL SIGN CERTIFICATE SIGNING REQUESTS (CSR) FROM GIVEN PUPPET AGENTS AND SENDS BACK THE SIGNED      #
# CERTIFICATES. IN A NUTSHELL, IT COPIES CSR FROM RELEVANT AGENT TO LOCAL DIRECTORY, SIGNS IT AND THEN COPIES THE  #
# SIGNED CERTIFICATE BACK TO THE AGENT. TO GENERATE KEYS AND CSR ON AGENTS, IT SSH AND EXECUTES A SCRIPT CALLED    #
# create_keys_and_csr.sh. IT USES SCP TO COPY THE CSRS AND SIGNED CERTIFICATES. AFTERWARDS, IT WILL EXECUTE A      #
# SCRIPT copy_certs_and_conf_to_kubernetes_directory.sh ON AGENTS TO COPY THE SIGNED CERTS AND PRIVATE KEYS OF     #
# AGENTS TO THE THEIR /etc/kubernetes DIRECTORY.                                                                   #
#                                                                                                                  #
####################################################################################################################
 
set -xe
 
CA_DIR=${CA_DIR:-~/kubernetes_ca}       #### WILL USE PROVIDED CA_DIR IF SET
CA_CERT_FILENAME="kubernetes_ca"        #### NEED TO BE SAME AS IN STEP 1 SCRIPT
CA_KEY_FILENAME="kubernetes_ca"         #### NEED TO BE SAME AS IN STEP 1 SCRIPT
 
########## CHANGE FOLLOWING PARAMETER VALUE BASED UPON YOUR SETUP ######
if [ -z "$1" ] ; then               # ONLY SET HOSTNAMES IF UNDEF
  PUPPET_AGENT_HOSTNAMES=(
    puppet-agent-01
    puppet-agent-02
    puppet-agent-03
    puppet-agent-04
  )
else
  PUPPET_AGENT_HOSTNAMES=( "$@" )
fi
 
COMMON_CLIENT_FILENAME="common-client"
FRONT_PROXY_CLIENT_FILENAME="front-proxy-client"
API_SERVER_KUBELET_CLIENT_FILENAME="apiserver-kubelet-client"
API_SERVER_FILENAME="apiserver"
 
LOCAL_TEMP_CSR_HOLDER_DIR_PREFIX=~/kubernetes-admin-
AGENT_TEMP_CSR_HOLDER_DIR=${AGENT_CSR_HOLDER_DIRECTORY:-~/kubernetes-certs}                     #### NEED TO BE SAME AS "AGENT_CSR_HOLDER_DIRECTORY" VARIABLE FROM substep_2_agent_bootstrap.sh
AGENT_SCRIPT_CREATE_KEYS_AND_CSR_ABSOLUTE_FILE_PATH=$(pwd)/substep_2_agent_bootstrap.sh
AGENT_SCRIPT_COPY_CERTS_AND_CONF_ABSOLUTE_FILE_PATH=$(pwd)/substep_2_final_step.sh
 
for AGENT in ${PUPPET_AGENT_HOSTNAMES[@]};
do
        echo -e "\n\n**************************************** processing files for $AGENT *****************************************************\n"
        LOCAL_DIR_PER_AGENT=$LOCAL_TEMP_CSR_HOLDER_DIR_PREFIX$AGENT
        mkdir -p $LOCAL_DIR_PER_AGENT
 
        echo -e "$HOSTNAME: \tRunning \"$AGENT_SCRIPT_CREATE_KEYS_AND_CSR_ABSOLUTE_FILE_PATH\" script on $AGENT......"
        ssh $AGENT sudo "KUBERNETES_CONTROLLER_AGENT_HOSTNAME=${PUPPET_AGENT_HOSTNAMES[0]}" "AGENT_CSR_HOLDER_DIRECTORY=${AGENT_CSR_HOLDER_DIRECTORY}" bash < $AGENT_SCRIPT_CREATE_KEYS_AND_CSR_ABSOLUTE_FILE_PATH
        echo -e "$HOSTNAME: \tRunning \"$AGENT_SCRIPT_CREATE_KEYS_AND_CSR_ABSOLUTE_FILE_PATH\" script on $AGENT......  -> DONE."
        scp $AGENT:$AGENT_TEMP_CSR_HOLDER_DIR/*.csr  $LOCAL_DIR_PER_AGENT
        scp $AGENT:$AGENT_TEMP_CSR_HOLDER_DIR/*.conf $LOCAL_DIR_PER_AGENT
 
        openssl x509 -req -in $LOCAL_DIR_PER_AGENT/$COMMON_CLIENT_FILENAME.csr -CA $CA_DIR/$CA_CERT_FILENAME.crt -CAkey $CA_DIR/$CA_KEY_FILENAME.key -CAcreateserial -out $LOCAL_DIR_PER_AGENT/$COMMON_CLIENT_FILENAME.crt -days 10000 -extensions v3_ext -extfile $LOCAL_DIR_PER_AGENT/$COMMON_CLIENT_FILENAME.conf
 
        scp $LOCAL_DIR_PER_AGENT/$COMMON_CLIENT_FILENAME.crt $AGENT:$AGENT_TEMP_CSR_HOLDER_DIR/
        echo -e "CA: \t COPIED COMMON-CLIENT CERTIFICATE TO $AGENT"
 
        scp $CA_DIR/$CA_CERT_FILENAME.crt $AGENT:$AGENT_TEMP_CSR_HOLDER_DIR/ca.crt
        echo -e "CA: \t COPIED CA CERTIFICATE TO $AGENT"
 
        scp $CA_DIR/$CA_CERT_FILENAME.crt $AGENT:$AGENT_TEMP_CSR_HOLDER_DIR/front-proxy-ca.crt
        echo -e "CA: \t COPIED FRONT-PROXY-CA CERTIFICATE TO $AGENT"
 
        openssl x509 -req -in $LOCAL_DIR_PER_AGENT/$FRONT_PROXY_CLIENT_FILENAME.csr -CA $CA_DIR/$CA_CERT_FILENAME.crt -CAkey $CA_DIR/$CA_KEY_FILENAME.key -CAcreateserial -out $LOCAL_DIR_PER_AGENT/$FRONT_PROXY_CLIENT_FILENAME.crt -days 10000 -extensions v3_ext -extfile $LOCAL_DIR_PER_AGENT/$FRONT_PROXY_CLIENT_FILENAME.conf
 
        scp $LOCAL_DIR_PER_AGENT/$FRONT_PROXY_CLIENT_FILENAME.crt $AGENT:$AGENT_TEMP_CSR_HOLDER_DIR/
        echo -e "CA: \t COPIED FRONT-PROXY-CLIENT CERTIFICATE TO $AGENT"
 
        openssl x509 -req -in $LOCAL_DIR_PER_AGENT/$API_SERVER_KUBELET_CLIENT_FILENAME.csr -CA $CA_DIR/$CA_CERT_FILENAME.crt -CAkey $CA_DIR/$CA_KEY_FILENAME.key -CAcreateserial -out $LOCAL_DIR_PER_AGENT/$API_SERVER_KUBELET_CLIENT_FILENAME.crt -days 10000 -extensions v3_ext -extfile $LOCAL_DIR_PER_AGENT/$API_SERVER_KUBELET_CLIENT_FILENAME.conf
 
        scp $LOCAL_DIR_PER_AGENT/$API_SERVER_KUBELET_CLIENT_FILENAME.crt $AGENT:$AGENT_TEMP_CSR_HOLDER_DIR/
        echo -e "CA: \t COPIED APISERVER-KUBELET-CLIENT CERTIFICATE TO $AGENT"
 
        openssl x509 -req -in $LOCAL_DIR_PER_AGENT/$API_SERVER_FILENAME.csr -CA $CA_DIR/$CA_CERT_FILENAME.crt -CAkey $CA_DIR/$CA_KEY_FILENAME.key -CAcreateserial -out $LOCAL_DIR_PER_AGENT/$API_SERVER_FILENAME.crt -days 10000 -extensions v3_ext -extfile $LOCAL_DIR_PER_AGENT/$API_SERVER_FILENAME.conf
 
        scp $LOCAL_DIR_PER_AGENT/$API_SERVER_FILENAME.crt $AGENT:$AGENT_TEMP_CSR_HOLDER_DIR/
        echo -e "CA: \t COPIED APISERVER CERTIFICATE TO $AGENT"
 
        echo -e "$HOSTNAME: \tRunning \"$AGENT_SCRIPT_COPY_CERTS_AND_CONF_ABSOLUTE_FILE_PATH\" script on $AGENT......"
        ssh $AGENT sudo "AGENT_CSR_HOLDER_DIRECTORY=${AGENT_CSR_HOLDER_DIRECTORY}" bash < $AGENT_SCRIPT_COPY_CERTS_AND_CONF_ABSOLUTE_FILE_PATH
        echo -e "$HOSTNAME: \tRunning \"$AGENT_SCRIPT_COPY_CERTS_AND_CONF_ABSOLUTE_FILE_PATH\" script ON $AGENT......  -> DONE."
        echo -e "\n********************************  processing files for $AGENT :  DONE  *****************************************************\n"
 
done;
