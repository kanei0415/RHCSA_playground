Vagrant.configure("2") do |config|
  config.vm.box = "almalinux/9"

  config.vm.network "public_network"

  config.vm.provider :vmware_desktop do |vmware|
    vmware.vmx["ethernet0.pcislotnumber"] = "160"
    vmware.vmx["ethernet1.pcislotnumber"] = "224"
  end


  config.vm.define "server-a" do |servera|
    servera.vm.hostname = "server-a"
    
    servera.vm.provider "vmware_desktop" do |v|
      v.cpus = 4
      v.memory = 4096
    end
  end

  config.vm.define "server-b" do |serverb|
    serverb.vm.hostname = "server-b"
    
    serverb.vm.provider "vmware_desktop" do |v|
      v.cpus = 4
      v.memory = 4096
    end
  end
end