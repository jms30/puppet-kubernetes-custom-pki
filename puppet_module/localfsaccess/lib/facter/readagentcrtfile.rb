# localfsaccess/lib/facter/readagentcrtfile.rb
Facter.add(:readagentcrtfile) do
  setcode do
    # return content of host specific Puppet certificate on executing agent.
    File.read('/etc/puppetlabs/puppet/ssl/certs/'+Facter::Core::Execution.execute('hostname')+'.pem')
  end
end
