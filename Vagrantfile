Vagrant.configure("2") do |config|
  config.vm.box = "almalinux/9"

  config.vm.network "public_network"
  config.vm.network "public_network"

  config.vm.provider :vmware_desktop do |vmware|
    vmware.vmx["ethernet0.pcislotnumber"] = "160"
    vmware.vmx["ethernet1.pcislotnumber"] = "224"
  end


  config.vm.define "server-01" do |server1|
    server1.vm.hostname = "server-01"
    
    server1.vm.provider "vmware_desktop" do |v|
      v.cpus = 4
      v.memory = 4096
    end
  end

  config.vm.define "server-02" do |server2|
    server2.vm.hostname = "server-02"
    
    server2.vm.provider "vmware_desktop" do |v|
      v.cpus = 4
      v.memory = 4096
    end
  end
end