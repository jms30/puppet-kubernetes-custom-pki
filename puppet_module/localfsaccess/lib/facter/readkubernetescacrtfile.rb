# localfsaccess/lib/facter/readkubernetescacrtfile.rb
Facter.add(:readkubernetescacrtfile) do
  setcode do
    # return content of ca.crt file located on executing agent.
    File.read('/etc/kubernetes/pki/ca.crt')
  end
end
