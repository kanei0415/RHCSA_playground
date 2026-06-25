Vagrant.configure("2") do |config|
  config.vm.box = "almalinux/9"

  config.vm.network "public_network"
  config.vm.network "public_network"

  config.vm.provider :vmware_desktop do |vmware|
    vmware.vmx["ethernet0.pcislotnumber"] = "160"
    vmware.vmx["ethernet1.pcislotnumber"] = "224"
  end

  (1..2).each do |i|
    config.vm.define "server-0#{i}" do |server|
      server.vm.hostname = "server-0#{i}"
      
      server.vm.provider "vmware_desktop" do |v|
        v.cpus = 4
        v.memory = 4096
      end
    end
  end
end