#!/bin/bash

if [ -z "$API_KEY" ]; then
  echo "Error: La variable de entorno API_KEY no está configurada."
  exit 1
fi
CONFIG_FILE="/home/ubuntu/CS_DEMO/overrides.yaml"
SHARED_KUBE_DIR="/usr/local/share/kube"
KUBECONFIG_PATH="$SHARED_KUBE_DIR/config"
sudo mkdir -p $SHARED_KUBE_DIR
sudo cp /etc/rancher/k3s/k3s.yaml $KUBECONFIG_PATH
sudo chmod 644 $KUBECONFIG_PATH
if ! grep -q "export KUBECONFIG=$KUBECONFIG_PATH" /etc/profile; then
    echo "export KUBECONFIG=$KUBECONFIG_PATH" | sudo tee -a /etc/profile
fi
source /etc/profile

if [[ -f "$CONFIG_FILE" ]]; then
  helm upgrade --namespace trendmicro-system --create-namespace --values /home/ubuntu/CS_DEMO/overrides.yaml https://github.com/trendmicro/cloudone-container-security-helm/archive/master.tar.gz
  AWS_REGION="us-east-1"
  REPOSITORY_NAME="demo-px-repo"

  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  REPOSITORY_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY_NAME}"
  aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
  git -C ./px-container-security-kubernetes pull origin main

  IMAGE_TAG="flask_app"
  docker build -t ${REPOSITORY_URI}:${IMAGE_TAG} ./px-container-security-kubernetes/${IMAGE_TAG}/
  docker push ${REPOSITORY_URI}:${IMAGE_TAG}

  export IMAGE_REGISTRY="$REPOSITORY_URI:$IMAGE_TAG"
  kubectl delete -f ./px-container-security-kubernetes/${IMAGE_TAG}/deployment.yaml
  envsubst < ./px-container-security-kubernetes/${IMAGE_TAG}/deployment.yaml | kubectl apply -f -

  IMAGE_TAG="ftp"
  docker build -t ${REPOSITORY_URI}:${IMAGE_TAG} ./px-container-security-kubernetes/${IMAGE_TAG}/
  docker push ${REPOSITORY_URI}:${IMAGE_TAG}

  export IMAGE_REGISTRY="$REPOSITORY_URI:$IMAGE_TAG"
  kubectl delete -f ./px-container-security-kubernetes/${IMAGE_TAG}/deployment.yaml
  envsubst < ./px-container-security-kubernetes/${IMAGE_TAG}/deployment.yaml | kubectl apply -f -

  IMAGE_TAG="ssh_bastion"
  docker build -t ${REPOSITORY_URI}:${IMAGE_TAG} ./px-container-security-kubernetes/${IMAGE_TAG}/
  docker push ${REPOSITORY_URI}:${IMAGE_TAG}

  export IMAGE_REGISTRY="$REPOSITORY_URI:$IMAGE_TAG"
  kubectl delete -f ./px-container-security-kubernetes/${IMAGE_TAG}/deployment.yaml
  envsubst < ./px-container-security-kubernetes/${IMAGE_TAG}/deployment.yaml | kubectl apply -f -

  IMAGE_TAG="django-app"
  sudo chmod 777 ./px-container-security-kubernetes/${IMAGE_TAG}/appcode/reset_db.sh
  sudo chmod 777 ./px-container-security-kubernetes/${IMAGE_TAG}/appcode/runapp.sh
  docker build -t ${REPOSITORY_URI}:${IMAGE_TAG} ./px-container-security-kubernetes/${IMAGE_TAG}/
  docker push ${REPOSITORY_URI}:${IMAGE_TAG}

  export IMAGE_REGISTRY="$REPOSITORY_URI:$IMAGE_TAG"
  kubectl delete -f ./px-container-security-kubernetes/${IMAGE_TAG}/deployment.yaml
  envsubst < ./px-container-security-kubernetes/${IMAGE_TAG}/deployment.yaml | kubectl apply -f -
else
  api_key_cs=$(curl --location 'https://api.xdr.trendmicro.com/v3.0/containerSecurity/kubernetesClusters' \
    --header 'Content-Type: application/json' \
    --header 'Accept: application/json' \
    --header "Authorization: Bearer $API_KEY" \
    --data '{
      "name": "Demo_Container_Hiram",
      "groupId": "00000000-0000-0000-0000-000000000000",
      "description": "",
      "policyId": "",
      "resourceId": ""
    }' | jq -r '.apiKey')
  echo "El archivo overrides no existe. Registrando una nueva API Key..."
  mkdir -p "$(dirname "$CONFIG_FILE")"
  cat << EOF > "$CONFIG_FILE"
cloudOne: 
    apiKey: $api_key_cs
    endpoint: https://container.us-1.cloudone.trendmicro.com
    exclusion: 
        namespaces: [kube-system]
    runtimeSecurity:
        enabled: true
    vulnerabilityScanning:
        enabled: true
    inventoryCollection:
        enabled: true
    exclusion:
        namespaces:
        - kube-system
        - trendmicro-system
        - calico-system
        - calico-apiserver
        - registry
        - metallb-system
        - tigera-operator
        - local-path-storage
        - ingress-nginx
scout:
  excludeSameNamespace: true
securityContext:
  scout:
    scout:
      allowPrivilegeEscalation: true
      privileged: true
EOF
  helm install trendmicro --namespace trendmicro-system --create-namespace --values /home/ubuntu/CS_DEMO/overrides.yaml https://github.com/trendmicro/cloudone-container-security-helm/archive/master.tar.gz

  AWS_REGION="us-east-1"
  REPOSITORY_NAME="demo-px-repo"

  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  REPOSITORY_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY_NAME}"
  aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

  kubectl create secret docker-registry ecr-secret --docker-server="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com" --docker-username=AWS --docker-password=$(aws ecr get-login-password --region "${AWS_REGION}") --docker-email=px-demo@trendmicro.com
  git clone https://github.com/XeniaP/px-container-security-kubernetes.git
  git -C ./px-container-security-kubernetes pull origin main

  IMAGE_TAG="flask_app"
  docker build -t ${REPOSITORY_URI}:${IMAGE_TAG} ./px-container-security-kubernetes/${IMAGE_TAG}/
  docker push ${REPOSITORY_URI}:${IMAGE_TAG}

  export IMAGE_REGISTRY="$REPOSITORY_URI:$IMAGE_TAG"
  envsubst < ./px-container-security-kubernetes/${IMAGE_TAG}/deployment.yaml | kubectl apply -f -

  IMAGE_TAG="ftp"
  docker build -t ${REPOSITORY_URI}:${IMAGE_TAG} ./px-container-security-kubernetes/${IMAGE_TAG}/
  docker push ${REPOSITORY_URI}:${IMAGE_TAG}

  export IMAGE_REGISTRY="$REPOSITORY_URI:$IMAGE_TAG"
  envsubst < ./px-container-security-kubernetes/${IMAGE_TAG}/deployment.yaml | kubectl apply -f -

  IMAGE_TAG="ssh_bastion"
  docker build -t ${REPOSITORY_URI}:${IMAGE_TAG} ./px-container-security-kubernetes/${IMAGE_TAG}/
  docker push ${REPOSITORY_URI}:${IMAGE_TAG}

  export IMAGE_REGISTRY="$REPOSITORY_URI:$IMAGE_TAG"
  envsubst < ./px-container-security-kubernetes/${IMAGE_TAG}/deployment.yaml | kubectl apply -f -
  
  IMAGE_TAG="django-app"
  sudo chmod 777 ./px-container-security-kubernetes/${IMAGE_TAG}/appcode/reset_db.sh
  sudo chmod 777 ./px-container-security-kubernetes/${IMAGE_TAG}/appcode/runapp.sh
  docker build -t ${REPOSITORY_URI}:${IMAGE_TAG} ./px-container-security-kubernetes/${IMAGE_TAG}/
  docker push ${REPOSITORY_URI}:${IMAGE_TAG}

  export IMAGE_REGISTRY="$REPOSITORY_URI:$IMAGE_TAG"
  kubectl delete -f ./px-container-security-kubernetes/${IMAGE_TAG}/deployment.yaml
  envsubst < ./px-container-security-kubernetes/${IMAGE_TAG}/deployment.yaml | kubectl apply -f -
fi


NAMESPACE="default"
PODS=($(sudo k3s kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'))
if [ ${#PODS[@]} -eq 0 ]; then
    echo "No se encontraron pods en el namespace '$NAMESPACE'."
    exit 1
fi
RANDOM_POD=${PODS[$RANDOM % ${#PODS[@]}]}
sudo echo "Pod seleccionado al azar: $RANDOM_POD"
sudo k3s kubectl exec -it "$RANDOM_POD" -n $NAMESPACE -- /bin/sh