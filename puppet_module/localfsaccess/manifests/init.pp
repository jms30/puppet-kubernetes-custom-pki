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
