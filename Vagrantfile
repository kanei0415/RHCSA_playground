# -*- mode: ruby -*-
# RHCSA Simulator Bootstrapper — M1 Mac (VMware Desktop / ARM64)

require 'fileutils'

TESTER_USER    = "tester"
TESTER_PASS    = "testpass"
NODE1_ROOT_PASS = "redhat"
NODE2_IP       = "192.168.56.102"
NODE1_IP       = "192.168.56.101"

Vagrant.configure("2") do |config|
  config.vm.box = "almalinux/9"

  # Common VMware settings for M1 Mac (ARM64)
  config.vm.provider :vmware_desktop do |v|
    v.vmx["ethernet0.pcislotnumber"] = "160"
    v.vmx["ethernet1.pcislotnumber"] = "224"
    v.gui          = false
    v.linked_clone = false
  end

  # Generate Ansible inventory.ini after all VMs are up
  config.trigger.after :up do |t|
    t.name = "Generate Ansible inventory"
    t.run  = { path: "scripts/gen_inventory.sh" }
  end

  # ================================================================
  # node1 — ネットワーク未設定 / 試験: ネットワーク・ユーザー・権限・autofs・圧縮
  # ================================================================
  config.vm.define "node1" do |n|
    n.vm.hostname = "node1.example.com"

    # Exam NIC: present but NOT configured in guest (exam task: configure it)
    n.vm.network "private_network", auto_config: false

    n.vm.provider :vmware_desktop do |v|
      v.vmx["memsize"]  = "2048"
      v.vmx["numvcpus"] = "2"
    end

    n.vm.provision "shell",
      path: "scripts/node1_bootstrap.sh",
      env: {
        "TESTER_USER"    => TESTER_USER,
        "TESTER_PASS"    => TESTER_PASS,
        "ROOT_PASS"      => NODE1_ROOT_PASS,
        "NODE2_IP"       => NODE2_IP
      }
  end

  # ================================================================
  # node2 — rootパスワード不明 / 試験: rootリカバリ・LVM・SWAP・コンテナ
  # ================================================================
  config.vm.define "node2" do |n|
    n.vm.hostname = "node2.example.com"

    # Exam NIC: configured
    n.vm.network "private_network", ip: NODE2_IP

    # Create extra VMDKs before the VM boots
    n.trigger.before :up do |t|
      t.name = "Create node2 extra disks (LVM/SWAP practice)"
      t.ruby do |_env, _machine|
        disks_dir = File.expand_path(".vagrant/disks")
        FileUtils.mkdir_p(disks_dir)

        vdisk_mgr = "/Applications/VMware Fusion.app/Contents/Library/vmware-vdiskmanager"

        { "sdb.vmdk" => "5120", "sdc.vmdk" => "3072" }.each do |name, mb|
          path = File.join(disks_dir, name)
          next if File.exist?(path)

          if File.exist?(vdisk_mgr)
            puts ">>> Creating #{name} (#{mb} MB)..."
            system(%(\"#{vdisk_mgr}\" -c -t 0 -s #{mb}MB -a lsilogic \"#{path}\"))
          else
            warn "WARN: vmware-vdiskmanager not found at:"
            warn "  #{vdisk_mgr}"
            warn "  Create #{path} manually (#{mb} MB sparse VMDK) or run:"
            warn "  make create-disks"
          end
        end
      end
    end

    n.vm.provider :vmware_desktop do |v|
      v.vmx["memsize"]  = "2048"
      v.vmx["numvcpus"] = "2"

      # Attach extra disks (created by trigger above)
      disks_dir = File.expand_path(".vagrant/disks")
      v.vmx["scsi0:1.present"]  = "TRUE"
      v.vmx["scsi0:1.fileName"] = File.join(disks_dir, "sdb.vmdk")
      v.vmx["scsi0:1.redo"]     = ""
      v.vmx["scsi0:2.present"]  = "TRUE"
      v.vmx["scsi0:2.fileName"] = File.join(disks_dir, "sdc.vmdk")
      v.vmx["scsi0:2.redo"]     = ""
    end

    n.vm.provision "shell",
      path: "scripts/node2_bootstrap.sh",
      env: {
        "TESTER_USER" => TESTER_USER,
        "TESTER_PASS" => TESTER_PASS,
        "NODE2_IP"    => NODE2_IP,
        "NODE1_IP"    => NODE1_IP
      }
  end
end
