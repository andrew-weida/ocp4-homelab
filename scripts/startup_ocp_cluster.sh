#!/bin/bash

# Function to check if KUBECONFIG env variable is set
check_kubeconfig() {
  if [ -z "$KUBECONFIG" ]; then
    echo "KUBECONFIG environment variable is not set. Exiting."
    exit 1
  fi

  if [ ! -f "$KUBECONFIG" ]; then
    echo "Kubeconfig file specified by KUBECONFIG does not exist. Exiting."
    exit 1
  fi
}

# Function to check if the API server is responding
check_api_server() {
    if oc get --raw '/healthz' &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to check if all nodes are ready
check_nodes_ready() {
    not_ready=$(oc get nodes | grep -E "NotReady" > /dev/null)
    if [ -z "$not_ready" ]; then
        return 0
    else
        return 1
    fi
}

# Function to approve pending CSRs
approve_csrs() {
    local pending_csrs
    pending_csrs=$(oc get csr | awk '/Pending/ {print $1}')
    if [ -n "$pending_csrs" ]; then
        echo "Approving pending CSRs..."
        echo "$pending_csrs" | xargs oc adm certificate approve
    else
        echo "No pending CSRs found."
    fi
}

# Function to check if all ClusterOperators are ready
check_cluster_operators_ready() {
    local not_ready
    not_ready=$(oc get clusteroperators --no-headers | awk '$3 != "True" || $4 != "False" || $5 != "False" {print $1}'| tr '\n' ' ')
    if [ -z "$not_ready" ]; then
        return 0
    else
        echo "The following Cluster Operators are still not ready: $not_ready"
        return 1
    fi
}

# Make sure KUBECONFIG is defined
check_kubeconfig

# Turn on master/worker nodes that are shutoff
virsh list --inactive --name | grep -E '^(master-|worker-)' | xargs -n1 virsh start

# Wait for API Server
echo "Waiting for the API server to be responsive..."
while true; do
    if check_api_server; then
        echo "API server is responsive."
        break
    else
        echo "API server is not responding. Waiting 30 seconds before next check..."
        sleep 30
    fi
done

# Wait for Nodes to Be Ready
echo "Waiting for all nodes to be ready..."
while ! check_nodes_ready; do
    echo "Some nodes are not ready yet. Checking for pending CSRs..."
    approve_csrs
    echo "Waiting 30 seconds before next check..."
    sleep 30
done

echo "All nodes are ready!"

echo "Mark all nodes as schedulable"
for node in $(oc get nodes -o jsonpath='{.items[*].metadata.name}'); do echo ${node} ; oc adm uncordon ${node} ; done

# Wait for ClusterOperators to Be Ready
echo "Waiting for all ClusterOperators to be ready..."
while ! check_cluster_operators_ready; do
    echo "Waiting 30 seconds before next check..."
    sleep 30
done

echo "All ClusterOperators are ready!"