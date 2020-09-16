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
3.	On agent VMs, your puppet.conf (`/etc/puppetlabs/puppet/puppet.conf`) must have an alternative DNS name because the ETCD is going to use that. The goal is to have a puppet agent certificate signed by the puppet master CA which will have DNS alternative names in the certificate, and that certificate will be used for ETCD communication. Add following line to the `puppet.conf` file : 
    
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

7.	Docker CE needs to be installed on the puppet master to run the `puppetlabs/kubetool` docker image. The version should be `>= 18.06.1-ce`. This step is necessary only if you want to run the script to generate a new `RedHat.yaml` file. If you don't want to generate a `RedHat.yaml` file, just use the uploaded `RedHat.yaml` file from the repo and adjust your ETCD Cluster hosts and IP address entries. 

8.	The puppet master's SSHability to all puppet agents. This will be needed to execute scripts that (a) generate private keys and Certificate Signing Requests(CSR) on agents, (b) copies the CSRs to the puppet master, (c) signing on master and then finally, (d) copying back the signed certificates to the corresponding agents. 

    To do so, on master execute following command 

9.	```console
    [root@puppet-master /home]# sudo -i 
    [root@puppet-master /home]# ssh-keygen
    ```
    
    Press Enter for all questions asked. Afterwards, copy the generated SSH Public key onto each agent.
    
    ```console
    [root@puppet-master /home]# ssh-copy-id <agent host name>
    ```

    ssh root

    > This will fail if your VM can't `ssh root@<remote machine>`



# Setup guide to use External Kubernetes Certificates

1.	On puppet master, you need to first generate a Kubernetes CA certificate and relevant private key. The CA certificate will be distributed to all agents for Kubernetes PKI certificate chain verification and the CA private key will be used to sign all Certificate Signing Requests (CSRs) from each agent that is working as a Kubernetes Node. To do so, grab `~/master/step_1_ca_bootstrap.sh` script and run the following command **on your master**. Please pay attention to variables in the script. Adjust them accordingly as needed.

    ```console
    [centos@puppet-master ~]$ CA_DIR=<provide your choice of path or just simply $PWD> ./step_1_ca_bootstrap.sh
    ```

    You can confirm whether the certificate and keys were generated in the $DIRECTORY folder configured in the script as follows:

    ```console
    [centos@puppet-master ~]$ ll /home/centos/kubernetes_ca/
    total 16
    -rw-rw-r-- 1 centos centos 1094 Jun  4 19:14 kubernetes_ca.crt
    -rw-rw-r-- 1 centos centos  236 Jun  4 19:14 kubernetes_ca_csr.conf
    -rw------- 1 centos centos 1675 Jun  4 19:14 kubernetes_ca.key
    ```
2.	After creating the Kubernetes CA, we need to create kubernetes related private keys and CSRs on each agent. The CSRs needed to be signed by our newly created Kubernetes CA and should be used as the external certificate on the agents for kubernetes communication. 

    ![alt text](images/Kubernetes_PKI.svg)

    front-proxy-ca.crt
    
    > the sake of this exercise, we will use `ca.crt` as `front-proxy-ca.crt`
    
    In addition to the aforementioned certs, we will also create another key/cert pair which will be used later for the Kubernetes configuration files. We will call it common-client. This will also be signed by the same kubernetes CA.

    ![alt text](images/Kubernetes_PKI_Common-Client.svg)

3.	Download the following scripts and put them into single folder. Then run the script `step_2_sync_agents.sh` with following command. This script will take care of creating all certs and keys from previous point.


    ```console
    [centos@puppet-master ~]$ sudo AGENT_CSR_HOLDER_DIRECTORY=<provide your choice of path> CA_DIR=<should be same as step 1 of this guide> ./step_2_sync_agents.sh <provide your space separated hostnames>
    ```

    Adjusting scripts

    >Please adjust variables in the scripts to accommodate your local directory setup. 

    service_cidr IP Address
    
    >In the `substep_2_agent_bootstrap.sh` script, you need to pay attention to variable `CNI_APISERVER_CONNECTION_ADDRESS`. The value of this variable is used in Apiserver certificate as the `Subject Alternate Name`. The purpose of doing so is to allow our CNI (in this case Cilium) pods to communicate with cluster services via Apiserver. Usually, if you do not change this, then it takes first address from the default address range of `10.96.0.0/12` , which is `10.96.0.1`. The address range can be changed by passing a different value as the `service_cidr parameter` for the `puppetlabs/kubernetes` module. You can do so with `RedHat.yaml` file or even by providing value in `manifest/site.pp` file on puppet-master for an appropriate worker node. If you wish to change the address range, then you must accommodate appropriate IP address for cluster service in the `CNI_APISERVER_CONNECTION_ADDRESS` parameter.

    Scripts => 
    * step_2_sync_agents.sh
    * substep_2_agent_bootstrap.sh
    * substep_2_final_step.sh

4. To confirm that all certificates are created on the agent, go to the agent and use `ll (ls -l)` command. You should see all necessary certs, keys and conf files.

    ```console    
    [root@puppet-agent-01 production]# ll /etc/kubernetes/pki/
    total 20
    -rw-------. 1 root root 1338 Jun  7 19:05 apiserver.crt
    -rw-------. 1 root root 1679 Jun  7 19:05 apiserver.key
    -rw-------. 1 root root 1159 Jun  7 19:05 apiserver-kubelet-client.crt
    -rw-------. 1 root root 1679 Jun  7 19:05 apiserver-kubelet-client.key
    -rw-------. 1 root root 1094 Jun  7 19:05 ca.crt
    -rw-------. 1 root root 1143 Jun  7 19:05 common-client.crt
    -rw-------. 1 root root 1679 Jun  7 19:05 common-client.key
    -rw-------. 1 root root 1095 Jun  7 19:07 front-proxy-ca.crt
    -rw-------. 1 root root   41 Jun  7 19:07 front-proxy-ca.key
    -rw-------. 1 root root 1111 Jun  7 19:05 front-proxy-client.crt
    -rw-------. 1 root root 1679 Jun  7 19:05 front-proxy-client.key
    -rw-------. 1 root root 1679 Jun  7 19:07 sa.key
    -rw-------. 1 root root  451 Jun  7 19:07 sa.pub

    [root@puppet-agent-01 production]# ll /etc/kubernetes/
    total 36
    -rw-------. 1 root root 5628 Jun  7 19:05 admin.conf
    -rw-------. 1 root root 2016 Jun  7 19:07 config.yaml
    -rw-------. 1 root root 5686 Jun  7 19:05 controller-manager.conf
    -rw-------. 1 root root 1970 Jun  7 19:05 kubelet.conf
    drwx------. 3 root root 4096 Jun  7 19:07 pki
    -rw-------. 1 root root 5649 Jun  7 19:05 scheduler.conf
    ```
5.	By this point, we have generated all of the necessary Kubernetes certs and config files on all future kubernetes nodes. Now, on puppet master, run the docker container for `puppetlabs/kubetool` that generates the \<OS\>.yaml, and agent specific yaml files. Use the script `~/master/step_3_generate_redhat.sh` that takes care of everything needed for the setup. Please adjust your agent hostnames and IP addresses in the script. Run the script with following command **on puppet master**.

    ```console
    [centos@puppet-master ~]$ sudo ./step_3_generate_redhat.sh
    ```

    Skipping this step
    
    > If you do not want to run this script (as it merely generates `RedHat.yaml` file in the end using a docker image internally), you can just grab an example `RedHat.yaml` file from the repository located at `~/master/RedHat.yaml`. Adjust parameters `'kubernetes::etcd_initial_cluster'`, `'kubernetes::etcd_peers'`, and `'kubernetes::controller_address'` with your network hosts and IP address in the file and place it on your `/etc/puppetlabs/code/environments/production/data` folder.

    controller address
    
    > Make sure that the `kubernetes::controller_address` value in `RedHat.yaml` and the IP address in the `clusters.cluster.server` parameter in `admin.conf` yaml file on any agent are the same. If not, then open your scripts `substep_2_final_step.sh` &  `substep_2_agent_bootstrap.sh` and update the `KUBERNETES_CONTROLLER_AGENT_HOSTNAME` variable with appropriate hostnames corresponding to the expected IP addresses, and finally run the `step_2_sync_agents.sh` from step 3 again. These values are going to be injected in the config files generated from those shell scripts so that nodes can communicate accordingly to the controller address.

    `ignore-preflight-errors`
    
    > In the previous script, we added a few lines to `RedHat.yaml` file:  `'ignore_preflight_errors'`. If you do not add them on a kubernetes worker, the installation fails. This flags indicates to the kubernetes worker to ignore when the `ca.crt` and `kubelet.conf` files already exist. The worker looks for `ca.crt` file when it starts, and if it does not find it, then it fails right away. If you place the `ca.crt` file (which the `step_2_sync_agents.sh` is doing for you), then it complains that there is an existing `ca.crt` file in the `/etc/kubernetes/pki` directory and fails too. Seems like a bug in the installation step from `puppetlabs/kubernetes` module. As for the `kubelet.conf`, we need to create one so that we can inject the Kubernetes CA signed `client-certificate-data` instead of letting the kubernetes module generate that. 

6.	Run the script `step_3_generate_redhat.sh`. Once it finishes you can see `RedHat.yaml` file generated in `/etc/puppetlabs/code/environments/production/data` directory. Open the `RedHat.yaml` file and remove the following sections/parameters and values.
    * kubernetes::etcd_ca_crt,
    * kubernetes::etcd_ca_key,
    * kubernetes::etcdclient_crt,
    * kubernetes::etcdclient_key,
    * kubernetes::kubernetes_ca_crt,
    * kubernetes::kubernetes_ca_key,
    * kubernetes::discovery_token_hash,
    * kubernetes::kubernetes_front_proxy_ca_crt,
    * kubernetes::kubernetes_front_proxy_ca_key

    These values are the ETCD and Kubernetes PKI information that the kubetool has generated and has written in this file to later inject in the kubernetes module. We want to remove this so that we can enforce puppet agent’s PKI and our own Kubernetes CA signed certificate information instead. 

7.	Now we need to force the agents to read from their local file system. For this, we need to write a puppet module and custom fact. First we develop custom facts. To do so, we will create a module directory and then will create custom facts inside the `lib/facter` directory of the module. Go to your modulepath at  `/etc/puppetlabs/code/environments/production/modules/`. Enter following command to create a module directory for a module name `‘localfsaccess’`. Please mind the case sensitivity as module names **only contain lowercase letters**. 

    ```console
    sudo mkdir -p localfsaccess/lib/facter
    ```

    Skipping this step
    
    > If you don't want to create following files on your own **[steps 7-11]**, just grab them from the  repository located at `~/puppet_module/localfsaccess/`. Copy the whole `localfsaccess` folder to your modulepath directory on master (located at `/etc/puppetlabs/code/environments/production/modules/`).

    Go to the `localfsaccess/lib/facter` folder and create a fact file named `‘readpuppetcacrtfile.rb’`. This will replace `“Kubernetes::etcd_ca_crt”` parameter of the `RedHat.yaml` file. Add following lines to the file: 

    ```puppet
    # localfsaccess/lib/facter/readpuppetcacrtfile.rb
    Facter.add(:readpuppetcacrtfile) do
        setcode do
            # return content of ca.pem file located on executing agent.
            File.read('/etc/puppetlabs/puppet/ssl/certs/ca.pem')
        end
    end
    ```

    With this fact, we are forcing agents to read a file of Puppet CA certificate on the local agents. 

8.	Similarly, create a new file named `‘readagentcrtfile.rb’` to use in place of `“Kubernetes::etcdclient_crt”`. Add following lines to the file: 

    ```puppet
	# localfsaccess/lib/facter/readagentcrtfile.rb
	Facter.add(:readagentcrtfile) do
        setcode do
            # return content of host specific Puppet certificate on executing agent. 
            File.read('/etc/puppetlabs/puppet/ssl/certs/'+Facter::Core::Execution.execute('hostname')+'.pem')
        end
    end
    ```

9.	And for corresponding private key, create a new custom fact file name `“readagentkeyfile.rb”` 
	
    ```puppet
    # localfsaccess/lib/facter/readagentkeyfile.rb
	Facter.add(:readagentkeyfile) do
        setcode do
            # return content of host specific private key file on executing agent.
            File.read('/etc/puppetlabs/puppet/ssl/private_keys/'+Facter::Core::Execution.execute('hostname')+'.pem')
        end
    end
    ```

10.	To enforce the agents to read kubernetes CA cert file from local directory, we create `readkubernetescacrtfile.rb` file. Add following contents to the file. 

    ```puppet
    # localfsaccess/lib/facter/readkubernetescacrtfile.rb
    Facter.add(:readkubernetescacrtfile) do
        setcode do
            # return content of ca.crt file located on executing agent.
            File.read('/etc/kubernetes/pki/ca.crt')
        end
    end
    ```
11.	Similarly, for the front-proxy-ca, we create a new fact called `readfrontproxycacrtfile`. Add following line to the file. 

    ```puppet
    # localfsaccess/lib/facter/readfrontproxycacrtfile.rb
    Facter.add(:readfrontproxycacrtfile) do
        setcode do
            # return content of front-proxy-ca.crt located on executing agent.
            File.read('/etc/kubernetes/pki/front-proxy-ca.crt')
        end
    end
    ```

12.	Now that we have created the facts, let’s create a module that utilizes these facts. Go to parent module directory and create manifest directory as `/etc/puppetlabs/code/environments/production/modules/localfsaccess/manifests`

13.	Create `init.pp` file in the manifests directory and add the following lines.  Please pay attention to `':'` in the notify command.

    ```puppet
    # localfsaccess/manifests/init.pp
    class localfsaccess (
        String $ca_cert = $facts['readpuppetcacrtfile'],
        String $agent_cert = $facts['readagentcrtfile'],
        String $agent_key = $facts['readagentkeyfile'],
        String $kubernetes_ca_cert = $facts['readkubernetescacrtfile'],
        String $front_proxy_ca_cert = $facts['readfrontproxycacrtfile'],
    )
    {
        notify{"The CA cert value is: ${ca_cert}": }
        notify{"The Agent cert value is: ${agent_cert}" :}
        notify{"The Agent key value is: ${agent_key}" :}
        notify{"The Kubernetes CA cert from /etc/kubernetes/pki is: ${kubernetes_ca_cert}" :}
        notify{"The Front proxy CA cert from /etc/kubernetes/pki value is: ${front_proxy_ca_cert}" :}
    }
    ```
    
    With this, we have now created our module named `‘localfsaccess’` that we can use to force agents to read specific files from their local file system. 
    
14.	We need to configure the `site.pp` file to enable our module. Go to `/etc/puppetlabs/code/environments/production/manifests/site.pp` and if you already have sections for each agents along with `kubernetes` class, then add following lines accordingly. 

    ```puppet
    node 'puppet-agent-01' {
        include localfsaccess
        class { 'kubernetes':
            controller => true,
            etcd_ca_crt => $localfsaccess::ca_cert,
            etcd_ca_key => "Foo. It doesn't matter.",
            etcdserver_crt => $localfsaccess::agent_cert,
            etcdclient_crt => $localfsaccess::agent_cert,
            etcdpeer_crt => $localfsaccess::agent_cert,
            etcdserver_key => $localfsaccess::agent_key,
            etcdclient_key => $localfsaccess::agent_key,
            etcdpeer_key => $localfsaccess::agent_key,
            kubernetes_ca_crt => $localfsaccess::kubernetes_ca_cert,
            kubernetes_ca_key => "Foo. It doesn't matter.",
            kubernetes_front_proxy_ca_crt => $localfsaccess::front_proxy_ca_cert,
            kubernetes_front_proxy_ca_key => "Foo. It doesn't matter.",
        }
    }
    ```

15.	We need to create couple of files in `/etc/kubernetes/pki` folder so that the created custom facts are loaded. Just create 2 files named `ca.crt` and `front-proxy-ca.crt` in `/etc/kubernetes/pki` folder with gibberish file contents (It's not going to be used anywhere. It's used only for loading custom facts). Confirm that those files reside in the directory: 

    ```console
    [root@puppet-master production]# ll /etc/kubernetes/pki/
    total 16
    -rw-r--r-- 1 root root 19 Jun  2 19:12 ca.crt
    -rw-r--r-- 1 root root 22 Jun  3 17:43 front-proxy-ca.crt	
    ```

16.	The `puppetlabs/kubernetes` module needs to be tweaked so that it does not perform unnecessary checks of CA private key. To do so, remove `ca.key` item from following line in `/etc/puppetlabs/code/environments/production/modules/kubernetes/manifests/config/kubeadm.pp`

    ```puppet
    $pki = ['ca.crt','ca.key','front-proxy-ca.crt','front-proxy-ca.key','sa.pub','sa.key']
    ```

    Restart puppet server afterwards 

    ```console
    systemctl restart pe-puppetserver.service
    ```

17.	We are ready on the puppet master side with all necessary information. So, it is time to restart puppetserver. Afterwards, check if the custom facts are loaded or not with following commands: 

    ```console
    [root@puppet-master production]# facter -p | grep -i "read*"
    readagentcrtfile => -----BEGIN CERTIFICATE-----
    readagentkeyfile => -----BEGIN RSA PRIVATE KEY-----
    readfrontproxycacrtfile => Foo.
    readkubernetescacrtfile => Foo.
    readpuppetcacrtfile => -----BEGIN CERTIFICATE-----
    ```

    This should not be empty. 

18.	On the agent side, you may be interested in removing all Kube* related data and tools (if they were previously installed) so that you have a clean slate on the puppet agents. This will also help the kubernetes module to install those tools (kubeadm, kubectl, kubelet ... etc) with next run attempt.  To do so, grab `~/agent/agent_cleanup.sh` script and run on each agent.

    If you want to have a clean slate on all agents between subsequent runs, then run this script on each agent every time 
    before you run the puppet agent. 


    `/etc/kubernetes` directory
    
    > If you are going to use this script to have clean agents, beware that the script also removes all files from `/etc/kubernetes/` directory. This includes all `.crt`, `.key` and `.conf` files which are generated and placed there by our shell scripts from step 3. So, **EVERYTIME YOU RUN THE `agent_cleanup.sh` SCRIPT, YOU NEED TO RUN `step_2_sync_agents.sh` SCRIPT ON MASTER SO THAT ALL NECESSARY CERTIFICATES, KEYS AND CONF FILES ARE REPLACED IN THE `/etc/kubernetes/` FOLDER**.

19.	 So, now when you run the puppet agent, you should see from the puppet logs that the kubernetes module has been installed successfully. 

# Conclusion

So it works. That's all we conclude. :laughing:


References:
1.	https://kubernetes.io/docs/reference/access-authn-authz/authentication/
2.	https://kubernetes.io/docs/concepts/cluster-administration/certificates/
3.	https://kubernetes.io/docs/setup/best-practices/certificates/#where-certificates-are-stored















