#!/usr/bin/env bash
 
#################################################################################
#                                                                               #
# THIS SCRIPT WILL REMOVE ALL KUBE* TOOLS AND RELEVANT DATA FOLDERS SO THAT THE #
# EXECUTING AGENT HAVE A CLEAN SLATE FOR NEXT RUN ATTEMPT.                      #
#                                                                               #
#################################################################################
 
 
sudo kubeadm reset -f
echo -e "Performed Kubeadm reset -> done."
 
sudo rm -v -r -f /etc/cni/net.d/*
echo -e "Removed cilinium data -> done."
 
sudo systemctl stop kubelet
echo -e "Stopped kubelet service -> done."
 
sudo systemctl stop kubeadm
echo -e "Stopped kubeadm service -> done."
 
sudo systemctl stop kubectl
echo -e "Stopped kubectl service -> done."
 
sudo systemctl stop puppet
echo -e "Stopped puppet service -> done."
 
sudo systemctl stop etcd
echo -e "Stopped etcd service -> done. "
 
sudo rm -r -f /etc/kubernetes/*
sudo rm -r -f ~/.kube/*
sudo rm -r -f /var/lib/etcd/*
echo -e "Removed kubernetes and etcd service folders -> done."
 
sudo yum -y remove kube*
echo -e "Removed kube* tools -> done. "
 
sudo systemctl disable etcd
sudo rm -f /etc/systemd/system/etcd*
sudo rm -f /usr/lib/systemd/system/etcd*
sudo rm -f /usr/local/bin/etcd*
echo -e "Removed etcd service and relevant metadata -> done. "
 
echo -e "WARNING: IF YOU WANT TO REMOVE PUPPET SSL CERTIFICATES, YOU NEED TO REMOVE FOLDER /etc/puppetlabs/puppet/puppet/ssl. THIS SCRIPT **DOES NOT** REMOVE THE PUPPET CERTS AND KEYS."
echo -e "Ready to play again..."
