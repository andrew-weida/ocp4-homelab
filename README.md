ocp4-homelab
=====================
Introduction
------------
I use these playbooks to install [**OpenShift Container Platform 4.x**](https://docs.openshift.com/container-platform/4.16/installing/installing_bare_metal/preparing-to-install-on-bare-metal.html); where instead of using bare metal nodes I use virtual machines on Intel based hosts, and simulate Redifish BMC using sushy-tools.


**Warning:** This project / repository / playbooks should be used **only for testing** OpenShift Container Platform 4.x and **NOT** for production environment.

Requirements
------------
### Operating System and packages
This has been tested on Fedora 40 and RHEL 8/9. Python/Ansible is required on the host.

The rest of the requirements are installed via the playbooks
- libvirt
- kcli
- qemu
- haproxy
- sushy-tools
- etc..


### vars/vm-nodes.yaml
This file is used to define the VMs that will make up your cluster, 

For example, the following will create VMs for a HA cluster with 2 worker nodes

```yaml
  master_nodes:
    - name: master-0
      baremetal_mac: 'aa:aa:aa:aa:01:02'
      baremetal_ip: 192.168.125.10
    - name: master-1
      baremetal_mac: 'aa:aa:aa:aa:01:03'
      baremetal_ip: 192.168.125.11
    - name: master-2
      baremetal_mac: 'aa:aa:aa:aa:01:04'
      baremetal_ip: 192.168.125.12
  worker_nodes:
    - name: worker-0
      baremetal_mac: 'aa:aa:aa:aa:01:05'
      baremetal_ip: 192.168.125.13
    - name: worker-1
      baremetal_mac: 'aa:aa:aa:aa:01:06'
      baremetal_ip: 192.168.125.14
```

### vars/variables.yaml
Most of the variables in here are self-explanatory, and the defaults can be used, but you'll probably want to update **cluster_name**, **base_domain** and maybe **ocp_version**. 

Note: You can enable ACM and GitOps operators during the install by setting install_acm and install_gitops variables to true

#### CPU/Memory/Disk

The memory/cpu/disk for the VM's are defined in this file. Additional disks (GB) can be added/removed to nodes by adding a item to the disks list. The example below would create 2 disks 150GB and 100GB for each node.

```yaml
master:
  cpu: 8
  memory: 20408
  disks: 
    - 150
    - 100
worker:
  cpu: 8
  memory: 32768
  disks: 
    - 150
    - 100
```

#### create_image_fs

The images for the VMs are created in /var/lib/libvirt/images, if the filesystem does not have enough disk space (750GB in the example), then you can set the variable **create_image_fs** to true. 
This will use LVM to allocate additional space using the disks you specify under **image_fs_disks**

```yaml
create_image_fs: true
image_fs_disks:
- /dev/sda
- /dev/nvme0n1
```

### vars/vault-variables.yaml

This is a ansible-vault that should contain the following variables  
```yaml
### password used for redfish bmc
secure_password: <PASSWORD>
# openshift pull secret
pull_secret: <OCP_PULL_SECRET>
# OPTIONAL: URL for Assisted Installer ISO if using Assisted Installer method instead of agent
ai_discovery_iso_url: <URL>
```

Install OpenShift Container Platform
--------------------------------
#### Clone this repo
```bash
git clone https://github.com/andrew-weida/ocp4-homelab.git
cd ocp4-homelab
```

#### Create the vault and .vaultpw file
```bash
cp vars/vault-variables.yaml.sample vars/vault-variables.yaml
ansible-vault encrypt vars/vault-variables.yaml
echo "your vault pw" > .vaultpw
```


#### Update inventory with your KVM/hypervisor host ip
```ini
[all]
kvm_host ansible_ssh_user=root ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' ansible_host=<KVM_HOST_IP>

```
#### Run the main.yaml playbook

```bash
ansible-playbook main.yaml
```

Provision VMs for ACM Inventory
--------------------------------
You can create VMs for ACM managed clusters after deployment of a hub cluster using the following variables to  `vars/vault-variables.yaml`:

```yaml
acm_managed:
  base_domain: home.arpa
  cluster_name: acm-managed
  vip:
    api: 192.168.125.90
    api_int: 192.168.125.90
    apps: 192.168.125.91
  master:
    cpu: 16
    memory: 12288
    disks: 
      - 150
  worker:
    cpu: 16
    memory: 12288
    disks: 
      - 150
acm_managed_domain: "{{ acm_managed.cluster_name }}.{{ acm_managed.base_domain }}"
```
Host variables should be added to `vars/vm-nodes.yaml` as follows:

```yaml
acm_managed_nodes:
  master_nodes:
    - name: acm-managed-master-0
      baremetal_mac: 'aa:aa:aa:aa:01:20'
      baremetal_ip: 192.168.125.16
    - name: acm-managed-master-1
      baremetal_mac: 'aa:aa:aa:aa:01:21'
      baremetal_ip: 192.168.125.17
    - name: acm-managed-master-2
      baremetal_mac: 'aa:aa:aa:aa:01:22'
      baremetal_ip: 192.168.125.18
  worker_nodes: []
      - name: acm-managed-worker-0
        baremetal_mac: 'aa:aa:aa:aa:01:23'
        baremetal_ip: 192.168.125.19
      - name: acm-managed-worker-2
        baremetal_mac: 'aa:aa:aa:aa:01:24'
        baremetal_ip: 192.168.125.20
      - name: acm-managed-worker-2
        baremetal_mac: 'aa:aa:aa:aa:01:25'
        baremetal_ip: 192.168.125.21
  worker_nodes: []
```

Then re-run prepare-vms:

```bash
ansible-playbook main.yml --tags prepare-vms
```