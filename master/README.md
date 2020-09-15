# Examples

## Step 1: Custom CA path
```
CA_DIR=$PWD ./step_1_ca_bootstrap.sh
```

## Step 2: Custom CRT path + custom hosts
```
sudo AGENT_CSR_HOLDER_DIRECTORY=/tmp/5 CA_DIR=$PWD ./step_2_sync_agents.sh centos8-1 centos8-2 centos8-3
```

## Step 3: Generate redhat with podman
```
sudo CONTAINER_CLI=podman ./step_3_generate_redhat.sh 
```
