# BETTER README coming 
CI/CD pipeline using Harness 

# Running my homelab/cloud with an AMD Ryzen Mini PC 16GB using PROXMOX as an orchestration solution for my VM's.

### On a blank ProxMox VM of an Ubuntu Flavour (Ubuntu 23.10 live server) install Docker 
```
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### On a blank ProxMox VM of an Ubuntu Flavour (Ubuntu 23.10 live server) deploy a Kubernetes Cluster 
### I used kubeadm since i was very interested in doing it the "hard way" and learning as much as possible. (https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
### Install the compatible CRI and the OCI runtimes (I used containerd and runc) and install cni-plugins. Generate and make appropriate changes to the /etc/containerd/config.toml 
```
apt install net-tools
sudo swapoff -a
cd /usr/local/
wget https://github.com/containerd/containerd/releases/download/v2.0.0/containerd-2.0.0-linux-amd64.tar.gz
tar Cxzvf /usr/local containerd-2.0.0-linux-amd64.tar.gz

cd /usr/local/lib/
mkdir systemd
cd systemd/
mkdir system
cd system/
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
systemctl daemon-reload
systemctl enable --now containerd
systemctl status containerd.service

cd /usr/local/sbin/
wget https://github.com/opencontainers/runc/releases/download/v1.2.1/runc.amd64
install -m 755 runc.amd64 /usr/local/sbin/runc
mkdir -p /opt/cni/bin
cd /opt/cni/bin/
wget https://github.com/containernetworking/plugins/releases/download/v1.6.0/cni-plugins-linux-amd64-v1.6.0.tgz
tar zxvf cni-plugins-linux-amd64-v1.6.0.tgz

mkdir /etc/containerd
touch etc/containerd/config.toml
containerd config default > /etc/containerd/config.toml
```
### Configure the systemd cgroup driver
### To use the systemd cgroup driver in /etc/containerd/config.toml with runc, set
```
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  ...
  
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true

sudo systemctl restart containerd
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg                         ### apt-transport-https may be a dummy package; if so, you can skip that package
```
### Download the public signing key for the Kubernetes package repositories. The same signing key is used for all repositories so you can disregard the version in the URL:
### If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
### sudo mkdir -p -m 755 /etc/apt/keyrings
```
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```
### Add the appropriate Kubernetes apt repository. 
### This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
```
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```
### Update the apt package index, install kubelet, kubeadm and kubectl, and pin their version:
```
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```
### Configure the Kubelet cgroup driver ( either through kubeadm-config.yaml , if you are using a file to execute kubeadm init OR under /var/lib/kubelet/config.yaml)
```
cgroupDriver: systemd
```
### Enable IPv4 packet forwarding
### sysctl params required by setup, params persist across reboots
```
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system
sysctl net.ipv4.ip_forward
```
### To initialize the control-plane node run ( you can use kubeadm-config.yaml and explicitly define your cluster cofiguration more https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/ OR you can run flags with kubeadm init )
```
kubeadm init --apiserver-advertise-address=<your VM private address IP of eth0)
export KUBECONFIG=/etc/kubernetes/admin.conf (use this command as a root user to enable kubectl command-line tool)
```

### Install CNI for the Kubernetes cluster
```
curl https://raw.githubusercontent.com/projectcalico/calico/v3.29.0/manifests/calico.yaml -O
kubectl apply -f calico.yaml
kubectl get pods -A
```
# CLUSTER IS READY!!!


### Build and push the Docker images to a DockerHub registry (you will have create an account https://hub.docker.com/ )
docker build -t kirillyesikov/notes .
docker push kirillyesikov/notes:latest

### In order to use this image with our deployment.yaml we will need to create a reference a secret
 kubectl create secret docker-registry <name> --docker-server=https://index.docker.io/v1/ --docker-username=<your username> --docker-password=<your password>

### I am using a one node cluster if you do untaint the node and create a namespace for our CI/CD deployed application.

kubectl taint node kirill node-role.kubernetes.io/control-plane:NoSchedule-
kubectl create namespace dev-ns


# NOW we have to either switch to Harness UI or use Harness CLI (https://www.harness.io/)
### This will download the Harness CLI (As I mentioned using Harness UI tool is perfectly fine)
curl -LO https://github.com/harness/harness-cli/releases/download/v0.0.25-Preview/harness-v0.0.25-Preview-linux-amd64.tar.gz 
tar -xvf harness-v0.0.25-Preview-linux-amd64.tar.gz 
export PATH="$(pwd):$PATH" 
echo 'export PATH="'$(pwd)':$PATH"' >> ~/.bash_profile

### Create API key and login to harness CLI (auto generated by Harness framework go to "Get Started" inside you project https://developer.harness.io/docs/platform/automation/api/api-quickstart/ )

harness login --api-key HARNESS-API-KEY --account-id HARNESS-ACCOUNT-ID

### Clone the repo
git clone https://github.com/kirillyesikov/pipelineDEMO.git
cd pipelineDEMO

### We will be creating a Harness secret ( using the PAT from your github repository)
harness secret apply --token GITHUB-PAT --secret-name "kirill_gitpat"

### Harness Delegate ( we will deploy a delegate inside the cluster using HELM)
helm repo add harness-delegate https://app.harness.io/storage/harness-download/delegate-helm-chart/
helm repo update harness-delegate
helm upgrade -i helm-delegate --namespace harness-delegate-ng --create-namespace \
  harness-delegate/harness-delegate-ng \
  --set delegateName=helm-delegate \
  --set accountId=n7brygS2SSSMAkd8ntpoYA \
  --set delegateToken=MjY0Y2FmYmI5Y2Y2MGZkOGI3ZDBhZmRhODVhMGViMjk= \
  --set managerEndpoint=https://app.harness.io \
  --set delegateDockerImage=harness/delegate:24.10.84200 \
  --set replicas=1 --set upgrader.enabled=true

### Harness Connectors (one GitHub connector to connect to our GitHub repository and a Kubernetes connector to connect to our Cluster)

harness connector --file github-connector.yml apply --git-user kirillyesikov

harness connector --file kubernetes-connector.yml apply --delegate-name helm-delegate

### Create a Service: Represents your application

harness service --file service.yml apply

### Create an Environment: Represents the production or non-production infrastructure

harness environment --file guestbook/harnesscd-pipeline/environment.yml apply

### Create an Infrastructure Definition: Specifies the target cluster for the infrastructure

harness infrastructure  --file infrastructure-definition.yml apply

### Create a pipeline with your preferred deployment strategy. I did Canary strategy as it reduces the probability of failed changes. 

harness pipeline --file kirill-canary-pipeline.yml apply


