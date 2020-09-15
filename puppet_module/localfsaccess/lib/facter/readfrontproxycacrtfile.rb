# localfsaccess/lib/facter/readfrontproxycacrtfile.rb
Facter.add(:readfrontproxycacrtfile) do
  setcode do
    # return content of front-proxy-ca.crt located on executing agent.
    File.read('/etc/kubernetes/pki/front-proxy-ca.crt')
  end
end
