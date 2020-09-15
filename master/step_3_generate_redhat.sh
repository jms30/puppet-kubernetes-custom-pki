#!/usr/bin/env bash
 
###########################################################################################
#                                                                                         #
#       STEP 3 OF WHOLE PROCESS. RUN ON MASTER WITH SUDO PRIVILEDGES.                     #
#                                                                                         #
# THIS SCRIPT WILL RUN A DOCKER IMAGE FOR PUPPETLABS/KUBETOOL THAT WILL GENERATE OS       #
# SPECIFIC YAML FILE (RedHat.yaml) IN /etc/puppetlabs/code/environments/production/data   #
# DIRECTORY. THE YAML FILE WILL BE Used AS INPUT IN INSTALLING THE PUPPETLABS/KUBERNETES  #
# MODULE ON AGENTS.                                                                       #
#                                                                                         #
###########################################################################################

set -xe 
 
##################### VARIABLES #######################
 
OS=RedHat       ## PLEASE MIND THE CASE SENSITIVITY.
 
ETCD_VERSION=3.4.8
 
KUBETOOL_VERSION=5.1.0
KUBERNETES_VERSION=1.18.0
 
CONTROLLER_ONE_HOSTNAME=puppet-agent-01
CONTROLLER_ONE_IP=192.168.42.129
CONTROLLER_TWO_HOSTNAME=puppet-agent-02
CONTROLLER_TWO_IP=192.168.42.130
CONTROLLER_THREE_HOSTNAME=puppet-agent-03
CONTROLLER_THREE_IP=192.168.42.131
 
ETCD_DEFAULT_CLUSTER="${CONTROLLER_ONE_HOSTNAME}:${CONTROLLER_ONE_IP},${CONTROLLER_TWO_HOSTNAME}:${CONTROLLER_TWO_IP},${CONTROLLER_THREE_HOSTNAME}:${CONTROLLER_THREE_IP}"
ETCD_INITIAL_CLUSTER="${ETCD_DEFAULT_CLUSTER:-${ETCD_INITIAL_CLUSTER}}"
DOCKER_CE_VERSION=18.06.1.ce-3.el7
MANAGE_DOCKER="${MANAGE_DOCKER:-true}"

CA_DIR=${CA_DIR:-~/kubernetes_ca}       ##### WILL USE PROVIDED CA_DIR IF SET
CUSTOM_CA_CERT_PATH=${CA_DIR}/kubernetes_ca.crt

DESTINATION_DIRECTORY=/etc/puppetlabs/code/environments/production/

#######################################################
 

mkdir -p $DESTINATION_DIRECTORY/data
cd $DESTINATION_DIRECTORY

rm -r -f data/*
 
${CONTAINER_CLI:-docker} run --rm \
-v $(pwd):/mnt:Z \
-e OS=${OS} \
-e VERSION=${KUBERNETES_VERSION} \
-e CONTAINER_RUNTIME=docker \
-e CNI_PROVIDER=cilium \
-e CNI_PROVIDER_VERSION=1.4.3 \
-e ETCD_INITIAL_CLUSTER=${ETCD_INITIAL_CLUSTER} \
-e ETCD_IP="%{networking.ip}" \
-e KUBE_API_ADVERTISE_ADDRESS="%{networking.ip}" \
-e INSTALL_DASHBOARD=true puppet/kubetool:${KUBETOOL_VERSION}
 
mv Redhat.yaml ${OS}.yaml
 
sed -i -e 's/1.18\/cilium/quick-install/g' ${OS}.yaml
sed -i -e 's/1.4.3\/examples/v1.7\/install/g' ${OS}.yaml
 
sed -i "17i kubernetes::etcd_version: ${ETCD_VERSION}" ${OS}.yaml
sed -i "18i kubernetes::etcd_archive: etcd-v${ETCD_VERSION}-linux-amd64.tar.gz" ${OS}.yaml
sed -i "19i kubernetes::etcd_source: https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz" ${OS}.yaml
 
sed -i "20i kubernetes::containerd_version: ${CONTAINERD_VERSION}" ${OS}.yaml
 
sed -i "21i kubernetes::manage_docker: ${MANAGE_DOCKER}" ${OS}.yaml
sed -i "22i kubernetes::docker_yum_baseurl: https://download.docker.com/linux/centos/7/x86_64/stable/" ${OS}.yaml
sed -i "23i kubernetes::docker_yum_gpgkey: https://download.docker.com/linux/centos/gpg" ${OS}.yaml
sed -i "24i kubernetes::docker_package_name: docker-ce" ${OS}.yaml
sed -i "25i kubernetes::docker_version: ${DOCKER_CE_VERSION}" ${OS}.yaml
 
PRINT_CA_CERT_SHA=$(openssl x509 -pubkey -in $CUSTOM_CA_CERT_PATH | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
echo -e "The CA Certificate SHA is : $PRINT_CA_CERT_SHA"
sed -i "26i kubernetes::discovery_token_hash: ${PRINT_CA_CERT_SHA}" ${OS}.yaml
 
sed -i "27i kubernetes::ignore_preflight_errors: " ${OS}.yaml
sed -i "28i - FileAvailable--etc-kubernetes-kubelet.conf" ${OS}.yaml
sed -i "29i - FileAvailable--etc-kubernetes-pki-ca.crt" ${OS}.yaml
 
 
mv ${OS}.yaml data/
