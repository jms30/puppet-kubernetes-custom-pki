# Problem Statement

The Puppet Kubernetes module from Puppetlabs comes with kube-tool. The tool is used to generate necessary configuration files (OS and each agent specific yaml files) that the agents will use to install and run a kubernetes cluster. The main problem with the tool’s file generation is that it creates PKI certificates and keys for Kubernetes eco systems. This includes PKI certificates as well as corresponding private keys which are later distributed over the network to subsequent puppet agents that are going to form the kubernetes cluster and relevant technologies cluster (i.e. etcd). This goes against the fundamentals of PKI: **the private key should never leave the owner**


# Investigation

One proposed solution to the problem is to utilize the puppet’s internal agent-master communication. The puppet agents have their own private keys and their corresponding certificates are signed by the puppet master at the bootstrapping phase. One of the goals of this project is to see whether we can utilize the puppet PKI information in the Kubernetes ecosystem.

Another proposed solution is to create our own Kubernetes CA chain. This includes creating private keys and Certificate Signing Requests(CSRs) on each kubernetes node and then sign them using Kubernetes CA certificate. With this approach, we completely eliminate the need for the kubetool in generating and distributing private keys and certificates. It will uphold PKI fundamentals since the private keys from the kubernetes nodes will never leave them. 

In the following guide, we use a hybrid of both of the approaches. (a). the first approach is used to perform ETCD communication and, (b) the second approach is used to perform Kubernetes communication. The reason for not using the first approach in Kubernetes communication is because of the specific requirements of Kubernetes related Certificates [e.g. Common Name, Organization info as well as specific Extensions and DNS names in the certificate.]


# Prerequisites

1.	For this exercise, we have 4 VMs. 1 VM will be a puppet master which has Puppet Enterprise installed. The other 3 VMs are running as puppet agents. 
2.	Each VM is pingable from the other VMs in the network. Make sure that each agent's hostname is resolvable on the puppet master. Check and if necessary add lines to `/etc/hosts`

    ```console
    [root@puppet-master production]# cat /etc/hosts

    127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
    ::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
    192.168.42.128	puppet-master puppet
    192.168.42.129	puppet-agent-01
    192.168.42.130	puppet-agent-02
    192.168.42.131	puppet-agent-03
    192.168.42.132	puppet-agent-04
    ```
3.	On agent VMs, your puppet.conf (`/etc/puppetlabs/puppet/puppet.conf`) must have an alternative DNS name because the ETCD is going to use that. The goal is to have a puppet agent certificate signed by the puppet master CA which will have DSN alternative names in the certificate, and that certificate will be used for ETCD communication. Add following line to the puppet.conf file : 
    
    ```puppet
    [main] 
    dns_alt_names=DNS:<your agent hostname>,IP:<your agent IP in the network>
    ```

    Afterwards, you need to restart your puppet agent service 
        
    ```console
    systemctl restart puppet
    ```

4.	On puppet master, to sign the incoming CSRs with alternate DNS names, add following line under `certificate-authority`  section in your ca.conf file located at `/etc/puppetlabs/puppetserver/conf.d/ca.conf`

    Under `certificate-authority` section:

    ```puppet
    allow-subject-alt-names: true
    ```

    Afterwards, restart your puppet server service with

    ```console
    systemctl restart pe-puppetserver.service
    ```

5.	The kubernetes module from Puppetlabs needs to be installed on the puppet master. To install the module, run the following command
    
    ```console
    puppet module install puppetlabs/kubernetes
    ```

6.	`site.pp` file on puppet master (located at `/etc/puppetlabs/code/environments/production/manifests/site.pp`) has entries for each puppet agent with relevant kubernetes module parameters. (i.e. `worker => true` OR `controller => true`). If you don't have entries, follow this guide. You will find relevant information to add at **step 14**.

7.	Docker CE needs to be installed on the puppet master to run the `puppetlabs/kubetool` docker image. The version should be `>= 18.06.1-ce`. This step is necessary only if you want to run the script to generate a new `RedHat.yaml` file. If you don't want to generate a `RedHat.yaml` file, just use the uploaded `RedHat.yaml` file from the BB repo and adjust your ETCD Cluster hosts and IP address entries. 

8.	The puppet master's SSHability to all puppet agents. This will be needed to execute scripts that (a) generate private keys and Certificate Signing Requests(CSR) on agents, (b) copies the CSRs to the puppet master, (c) signing on master and then finally, (d) copying back the signed certificates to the corresponding agents. 

    To do so, on master execute following command 

9.	```console
    [root@puppet-master /home]#sudo -i 
    [root@puppet-master /home]#ssh-keygen
    ```
    
    Press Enter for all questions asked. Afterwards, copy the generated SSH Public key onto each agent.
    
    ```console
    [root@puppet-master /home]#ssh-copy-id <agent host name>
    ```

    ssh root
    
    This will fail if your VM can't `ssh root@<remote machine>`

