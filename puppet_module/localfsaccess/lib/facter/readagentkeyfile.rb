# localfsaccess/lib/facter/readagentkeyfile.rb
Facter.add(:readagentkeyfile) do
  setcode do
    # return content of host specific private key file on executing agent.
    File.read('/etc/puppetlabs/puppet/ssl/private_keys/'+Facter::Core::Execution.execute('hostname')+'.pem')
  end
end
