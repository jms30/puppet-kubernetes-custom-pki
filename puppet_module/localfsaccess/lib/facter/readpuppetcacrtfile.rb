# localfsaccess/lib/facter/readpuppetcacrtfile.rb
Facter.add(:readpuppetcacrtfile) do
  setcode do
    # return content of ca.pem file located on executing agent.
    File.read('/etc/puppetlabs/puppet/ssl/certs/ca.pem')
  end
end
