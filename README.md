# GKE with Terraform
Google Kubernetes Engine (GKE) with Terraform.

## Prerequisites

1. Create [GCP](https://console.cloud.google.com) account
2. Install [Google SDK (gcloud CLI)](https://cloud.google.com/sdk/docs/install)
3. Install [Terraform](https://www.terraform.io/downloads.html)
4. Install [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

## Set up GCP.

We will need to create a project and a service account with sufficient permissions.

> Google Cloud Projects need to be globally unique.

1. Login to Google Cloud:

```bash
gcloud auth application-default login
```

2. Create new [project](https://cloud.google.com/resource-manager/docs/creating-managing-projects#gcloud):

```bash
# Project name: A human-readable name for your project.
# Project ID: A globally unique identifier for your project.
# Project number: An automatically generated unique identifier for your project.

export PROJECT_ID=gke-$(date +%d%m%Y%H%M%S)-test

gcloud projects create $PROJECT_ID
```

Check if the project created successfully:

```bash
# List the projects
gcloud projects list

# The output is as follows.
PROJECT_ID               NAME                     PROJECT_NUMBER
gke-14042023122152-test  gke-14042023122152-test  992211651197
```

3. Create service account and confirm:

```bash
# Creation
gcloud iam service-accounts create gke-sa-test \
    --project $PROJECT_ID \
    --display-name gke-sa-test 

# Confirmation
gcloud iam service-accounts list --project $PROJECT_ID

# The output is as follows.
DISPLAY NAME  EMAIL                                                        DISABLED
gke-sa-test   gke-sa-test@gke-14042023122152-test.iam.gserviceaccount.com  False
```

4. Create key for service account and store to local file and confirm:

```bash
# Creation
gcloud iam service-accounts \
    keys create gkesa_acc.json \
    --iam-account gke-sa-test@$PROJECT_ID.iam.gserviceaccount.com \
    --project $PROJECT_ID

# Check local file
cat gkesa_acc.json

# Confirmation
gcloud iam service-accounts \
    keys list \
    --iam-account gke-sa-test@$PROJECT_ID.iam.gserviceaccount.com \
    --project $PROJECT_ID
```

5. Assign **owner** role to service account:

```bash
gcloud projects \
    add-iam-policy-binding $PROJECT_ID \
    --member serviceAccount:gke-sa-test@$PROJECT_ID.iam.gserviceaccount.com \
    --role roles/owner
```

6. Assign to enviroment variable, starting with [TF_VAR](https://developer.hashicorp.com/terraform/cli/config/environment-variables), the project id.

```bash
# Use the following if you export in the same session.
export TF_VAR_project_id=$PROJECT_ID

# If you do not export in the same session or another day use the below:
export TF_VAR_project_id=14042023122152

# Or you can use the following:
export TF_VAR_project_id=$(gcloud projects list | grep -E "^gke-[0-9]+-test" | awk '{print $1}' | sed -E 's/^gke-([0-9]+)-test$/\1/')
```

## Google Cloud Platform Provider - Terraform

For more information please visit and read the official [documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs).

In Terraform definitions are split, in general, into 4 groups:

    1. provider
    2. variables
    3. resource
    4. output

For the first initialization we need the following files/configs:

```bash
├── gkesa_acc.json
├── provider.tf
└── variables.tf
```

In order to find the valid or stable versions of Kuberbetes:

```bash
gcloud container get-server-config --region europe-north1 --format=json | jq -r '.validNodeVersions[2]'

# Default version
gcloud container get-server-config --flatten="channels" --filter="channels.channel=STABLE" --format="yaml(channels.channel,channels.defaultVersion)" --region="europe-north1"

# Available versions
gcloud container get-server-config --flatten="channels" --filter="channels.channel=STABLE" --format="yaml(channels.channel,channels.validVersions)" --region="europe-north1"
```

Initialize the project:

```bash
terraform init
```

Apply the changes:

```bash
terraform apply
```

### provider.tf

- credentials: This parameter specifies the path to the JSON key file for the Google Cloud Service Account. In this case, it's "gkesa_acc.json". This JSON key file contains the necessary credentials to authenticate to GCP.
- project: The GCP project ID, obtained from the var.project_id variable. This is the project where the resources defined in your Terraform configuration will be created.
- region: The default region for resources that require a region parameter, obtained from the var.region variable. You can override this default region for specific resources by specifying a different region or location parameter in the resource configuration.

## Creating the Control Plane

We will use the [google_container_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster.html) module to create the control plane in GKE.

With ***controlPlane.tf*** configuration file we define the following:

### controlPlane.tf

- name: The name of the GKE cluster, obtained from the var.cluster_name variable.
- location: The location (region or zone) where the cluster is deployed, obtained from the var.region variable.
- remove_default_node_pool: A boolean setting that, when set to true, removes the default node pool created by GKE. This allows you to manage your node pools separately with the google_container_node_pool resource.
- initial_node_count: The initial number of nodes for the cluster. In this case, it's set to 1. However, since you are removing the default node pool, this setting won't have an impact on the final cluster.
- min_master_version: The minimum version of the Kubernetes control plane (master) in the cluster, obtained from the var.k8s_version variable.

```bash
.
├── controlPlane.tf
├── gkesa_acc.json
├── provider.tf
├── terraform.tfstate
└── variables.tf
```

```bash
# Sets an environment variable named K8s_VER with the value 1.24.11-gke.1000
export K8s_VER='1.24.11-gke.1000'

# if you don't want to type k8s version or enviroment then execute the command as below:
terraform apply --var k8s_version=$K8s_VER --var environment=test
```

We'll fetch the nodes of our new Kubernetes cluster by first creating a kubeconfig file to access it. Since we might not remember the cluster's name, region, and project, we can use Terraform outputs to obtain this information from the Terraform state. This method showcases another valuable Terraform feature while generating the necessary kubeconfig file.

By running the following command, you are configuring the kubectl command-line tool to use the credentials and context for the GKE cluster created by your Terraform configuration. Once configured, you can use kubectl to interact with your GKE cluster.

```bash
gcloud container clusters get-credentials $(terraform output --raw cluster_name) --project $(terraform output --raw project_id) --region $(terraform output --raw region)
```

```bash
.
├── controlPlane.tf
├── gkesa_acc.json
├── output.tf
├── provider.tf
├── terraform.tfstate
├── variables.tf
```

### output.tf

- cluster_name output:
	- The name of this output is "cluster_name".
	- The value of this output is obtained from the var.cluster_name variable. It will display the name of the GKE cluster created in your Terraform configuration.
- region output:
	- The name of this output is "region".
	- The value of this output is obtained from the var.region variable. It will display the region where the GKE cluster is deployed.
- project_id output:
	- The name of this output is "project_id".
	- The value of this output is obtained from the var.project_id variable. It will display the Google Cloud Platform project ID where the GKE cluster and other resources are created.

Now we must create a clusterrolebinding that grants the cluster-admin role to the user, giving full control over all resources in the Kubernetes cluster. 

```bash
# Cluster Admin
kubectl create clusterrolebinding cluster-admin-binding --clusterrole cluster-admin --user $(gcloud config get-value account)

# Retrieves information about all nodes in cluster.
kubectl get nodes -o wide
```

## Creating Worker Nodes

We will use the [google_container_node_pool](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool.html) module to create the worker nodes in GKE.

This configuration creates a node pool in the specified GKE cluster, with the desired node settings, and configures autoscaling, management, and timeout settings.

### workerNodes.tf

- name: The name of the node pool, obtained from the var.cluster_name variable.
- location: The location (region or zone) where the node pool is deployed, obtained from the var.region variable.
- cluster: The GKE cluster to which this node pool belongs, specified by the google_container_cluster.primary.name reference, which points to the cluster name in the google_container_cluster resource.
- version: The Kubernetes version for nodes in this node pool, obtained from the var.k8s_version variable.
- initial_node_count: The initial number of nodes in the node pool, obtained from the var.min_node_count variable.
- node_config block: Specifies the configuration for nodes in the node pool.
	- preemptible: A boolean setting that determines whether nodes in the node pool are preemptible, obtained from the var.preemptible variable. Preemptible nodes are less expensive but can be terminated by Google at any time.
	- machine_type: The machine type for nodes in the node pool, obtained from the var.machine_type variable.
	- oauth_scopes: The OAuth 2.0 scopes for the node's API access. In this case, nodes are granted access to Google Cloud Platform APIs.
- autoscaling block: Configures autoscaling settings for the node pool.
	- min_node_count: The minimum number of nodes in the node pool, obtained from the var.min_node_count variable.
	- max_node_count: The maximum number of nodes in the node pool, obtained from the var.max_node_count variable.
- management block: Configures the management settings for the node pool.
	- auto_upgrade: A boolean setting that controls whether nodes are automatically upgraded to the latest Kubernetes version. In this case, it's set to false, meaning nodes won't be upgraded automatically.
- timeouts block: Specifies custom timeouts for create and update operations.
	- create: The timeout for the create operation, set to 15 minutes.
	- update: The timeout for the update operation, set to 1 hour.


```bash
terraform apply --var k8s_version=$K8s_VER --var environment=test
```

***We created a GKE cluster using infrastructure as code (IaC) with Terraform!***

## Destroying the Cluster and resources.

To destroy all resources created by Terraform configuration execute the following command:

```bash
terraform destroy --var k8s_version=$K8s_VER --var environment=test
```

To delete the service account and project use the following:

```bash
# Get PROJECT_ID
export PROJECT_ID=$(gcloud projects list | grep -E "^gke-[0-9]+-test" | awk '{print $1}')

# Get service account
export SA_GKE=$(gcloud iam service-accounts list --project $PROJECT_ID | grep gke-sa-test | awk '{print $2}')

# Delete service account
gcloud iam service-accounts delete $SA_GKE  --project $PROJECT_ID

# Delete project
gcloud  projects delete $PROJECT_ID
```