#!/usr/bin/env bash
 
###################################################################################################################
#                                                                                                                 #    
#       A SUBSTEP OF STEP 2 SCRIPT. DO NOT INVOKE EXPLICITLY. THIS GETS INVOKED BY STEP 2 SCRIPT INTERNALLY.      #
#                                                                                                                 #
# THIS SCRIPT WILL COPY ALL SIGNED CERTIFICATES AND KEYS FROM SOURCE DIRECTORY TO DESTINATION DIRECTORY. THE GOAL #
# IS TO COPY ALL CERTS AND PRIVATE KEYS TO /etc/kubernetes/pki FOLDER. IN ADDITION, IT ALSO GENERATES KUBERNETES  #
# CONFIGURATION FILES AND COPIES TO /etc/kubernetes/ FOLDER.                                                      #
#                                                                                                                 #
###################################################################################################################
 
set -xe 
 
###########################################       VARIABLES       ###############################################
 
HOSTNAME=$(hostname)
DESTINATION_DIR=/etc/kubernetes
DESTINATION_PKI_DIR=$DESTINATION_DIR/pki
 
AGENT_CSR_HOLDER_DIRECTORY=${AGENT_CSR_HOLDER_DIRECTORY:-~/kubernetes-certs}            ###### NEEDS TO BE SAME AS "AGENT_TEMP_CSR_HOLDER_DIR" VARIABLE FROM STEP 2 SCRIPT.
 
KUBERNETES_CONTROLLER_AGENT_HOSTNAME=puppet-agent-01                                    ###### NEEDS TO BE THE FIRST HOSTNAME OF YOUR kubernetes::etcd_initial_cluster VARIABLE IN GENERATED REDHAT.YAML FILE
                                                                                        ###### OR THE FIRST HOSTNAME OF YOUR STEP 3 SCRIPT.
KUBERNETES_CONTROLLER_ADDRESS=$(grep -F "$KUBERNETES_CONTROLLER_AGENT_HOSTNAME" "/etc/hosts" | awk '{ print $1}')
 
COMMON_CLIENT_FILENAME="common-client"
FRONT_PROXY_CLIENT_FILENAME="front-proxy-client"
API_SERVER_KUBELET_CLIENT_FILENAME="apiserver-kubelet-client"
API_SERVER_FILENAME="apiserver"
FRONT_PROXY_CA_FILENAME="front-proxy-ca"
CA_FILENAME="ca"
 
##################################################################################################################
 
 
mkdir -p $DESTINATION_PKI_DIR
 
echo -e "$HOSTNAME: \tCopying all files to $DESTINATION_PKI_DIR folder."
/bin/cp -f $AGENT_CSR_HOLDER_DIRECTORY/*.crt  $DESTINATION_PKI_DIR
/bin/cp -f $AGENT_CSR_HOLDER_DIRECTORY/*.key  $DESTINATION_PKI_DIR
echo -e "$HOSTNAME: \tCopying all files to $DESTINATION_PKI_DIR folder. -> DONE."
 
 
 
###########################################  ADMIN.CONF FILE ######################################################
 
echo -e "$HOSTNAME: \tGenerating admin.conf file:"
tee $DESTINATION_DIR/admin.conf <<-EOF
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: $(base64 -w 0 < $AGENT_CSR_HOLDER_DIRECTORY/$CA_FILENAME.crt)
    server: https://$KUBERNETES_CONTROLLER_ADDRESS:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubernetes-admin
  name: kubernetes-admin@kubernetes
current-context: kubernetes-admin@kubernetes
kind: Config
preferences: {}
users:
- name: kubernetes-admin
  user:
    client-certificate-data: $(base64 -w 0 < $AGENT_CSR_HOLDER_DIRECTORY/$COMMON_CLIENT_FILENAME.crt)
    client-key-data: $(base64 -w 0 < $AGENT_CSR_HOLDER_DIRECTORY/$COMMON_CLIENT_FILENAME.key)
  
EOF
echo -e "$HOSTNAME: \tGenerating admin.conf file -> done."
 
##################################################################################################################
         
           
######################################   KUBELET.CONF FILE   #####################################################
 
echo -e "$HOSTNAME: \tGenerating kubelet.conf file:"
tee $DESTINATION_DIR/kubelet.conf <<-EOF
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: $(base64 -w 0 < $AGENT_CSR_HOLDER_DIRECTORY/$CA_FILENAME.crt)
    server: https://$KUBERNETES_CONTROLLER_ADDRESS:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: system:node:$(hostname)
  name: system:node:$(hostname)@kubernetes
current-context: system:node:$(hostname)@kubernetes
kind: Config
preferences: {}
users:
- name: system:node:$(hostname)
  user:
    client-certificate: $DESTINATION_PKI_DIR/$COMMON_CLIENT_FILENAME.crt
    client-key: $DESTINATION_PKI_DIR/$COMMON_CLIENT_FILENAME.key
EOF
echo -e "$HOSTNAME: \tGenerating kubelet.conf file -> done."
 
##################################################################################################################
     
 
#################################    CONTROLLER-MANAGER.CONF    ##################################################
 
echo -e "$HOSTNAME: \tGenerating controller-manager.conf file:"
 
tee $DESTINATION_DIR/controller-manager.conf <<-EOF
 
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: $(base64 -w 0 < $AGENT_CSR_HOLDER_DIRECTORY/$CA_FILENAME.crt)
    server: https://$KUBERNETES_CONTROLLER_ADDRESS:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: system:kube-controller-manager
  name: system:kube-controller-manager@kubernetes
current-context: system:kube-controller-manager@kubernetes
kind: Config
preferences: {}
users:
- name: system:kube-controller-manager
  user:
    client-certificate-data: $(base64 -w 0 < $AGENT_CSR_HOLDER_DIRECTORY/$COMMON_CLIENT_FILENAME.crt)
    client-key-data: $(base64 -w 0 < $AGENT_CSR_HOLDER_DIRECTORY/$COMMON_CLIENT_FILENAME.key)
 
  
EOF
echo -e "$HOSTNAME: \tGenerating controller-manager.conf file -> done."
 
##################################################################################################################
        
 
 
#########################################  SCHEDULER.CONF   ######################################################
 
echo -e "$HOSTNAME: \tGenerating scheduler.conf file:"
tee $DESTINATION_DIR/scheduler.conf <<-EOF
 
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: $(base64 -w 0 < $AGENT_CSR_HOLDER_DIRECTORY/$CA_FILENAME.crt)
    server: https://$KUBERNETES_CONTROLLER_ADDRESS:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: system:kube-scheduler
  name: system:kube-scheduler@kubernetes
current-context: system:kube-scheduler@kubernetes
kind: Config
preferences: {}
users:
- name: system:kube-scheduler
  user:
    client-certificate-data: $(base64 -w 0 < $AGENT_CSR_HOLDER_DIRECTORY/$COMMON_CLIENT_FILENAME.crt)
    client-key-data: $(base64 -w 0 < $AGENT_CSR_HOLDER_DIRECTORY/$COMMON_CLIENT_FILENAME.key)
 
EOF
echo -e "$HOSTNAME: \tGenerating scheduler.conf file -> done."
 
##################################################################################################################
 
echo -e "$HOSTNAME: \t\t\tTree structure of generated files. Confirm files and directory structure..."
tree $DESTINATION_DIR || find $DESTINATION_DIR # Use find if tee not available
