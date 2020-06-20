#!/bin/bash

echo "[TASK 1] Install docker container engine"
apt-get remove docker docker-engine docker.io containerd runc #> /dev/null 2>&1
apt-get update > /dev/null 2>&1
apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common  #> /dev/null 2>&1
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - #> /dev/null 2>&1
apt-get update > /dev/null 2>&1
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic test"
#apt-get install docker-ce docker-ce-cli containerd.io #> /dev/null 2>&1
apt install docker.io


echo "[TASK 2] Enable and start docker service"
systemctl enable docker >/dev/null 2>&1
systemctl start docker

# Add repo for kubernetes
echo "[TASK 3] Add repo for kubernetes"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
sudo apt-get update

# Install Kubernetes
echo "[TASK 4] Install Kubernetes [kubeadm, kubelet and kubectl] "
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Start and Enable kubelet service
echo "[TASK 5] Enable and start kubelet service"
systemctl enable kubelet >/dev/null 2>&1
echo 'KUBELET_EXTRA_ARGS="--fail-swap-on=false"' > /etc/default/kubelet 
systemctl start kubelet >/dev/null 2>&1


echo "[TASK 7] Set root password"
echo "kubeadmin" | passwd --stdin root >/dev/null 2>&1


# Hack required to provision K8s v1.15+ in LXC containers
#mknod /dev/kmsg c 1 11
#chmod +x /etc/rc.d/rc.local
#echo 'mknod /dev/kmsg c 1 11' >> /etc/rc.d/rc.local


#######################################
# To be executed only on master nodes #
#######################################

if [[ $(hostname) =~ *master.* ]]
then

  # Initialize Kubernetes
  echo "[TASK 9] Initialize Kubernetes Cluster"
  kubeadm init --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=all #>> /root/kubeinit.log 2>&1

  # Copy Kube admin config
  echo "[TASK 10] Copy kube admin config to root user .kube directory"
  mkdir /root/.kube
  cp /etc/kubernetes/admin.conf /root/.kube/config

  # Deploy flannel network
  echo "[TASK 11] Deploy flannel network"
  kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml > /dev/null 2>&1

  # Generate Cluster join command
  echo "[TASK 12] Generate and save cluster join command to /joincluster.sh"
  joinCommand=$(kubeadm token create --print-join-command 2>/dev/null) 
  echo " $joinCommand --ignore-preflight-errors=all " > ./joincluster.sh
fi
