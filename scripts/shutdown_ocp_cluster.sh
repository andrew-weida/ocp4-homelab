#!/bin/bash

USER=$(oc whoami 2> /dev/null)
if [[ $? -ne 0 ]]
then
    echo "ERROR: you must be logged into openshift to use this script"
    exit 1
fi

for node in $(oc get nodes -o jsonpath='{.items[*].metadata.name}'); do echo ${node} ; oc adm cordon ${node} ; done
for node in $(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[*].metadata.name}'); do echo ${node} ; oc adm drain ${node} --delete-emptydir-data --ignore-daemonsets=true --timeout=15s --force ; done
for node in $(oc get nodes -o jsonpath='{.items[*].metadata.name}'); do oc debug node/${node} -- chroot /host shutdown -h 1; done

check_vms_shutdown() {
    running_vms=$(virsh list --state-running --name | grep -E '^(master-|worker-)')
    if [ -z "$running_vms" ]; then
        return 0
    else
        return 1
    fi
}

echo "Waiting for all master and worker VMs to finnish shutting down..."

while ! check_vms_shutdown; do
    echo "Some master or worker VMs are still in the process of shutting down. Waiting 30 seconds before checking again..."
    sleep 30
done

echo "OCP Cluster has been Shutdown!"
