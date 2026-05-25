
REGISTRY_URL=registry1.dso.mil
FLUX_SECRET=private-registry
WAIT_TIMEOUT=300
NAMESPACE=flux-system
REGISTRY_USERNAME=${REGISTRY1_USERNAME:-}
REGISTRY_PASSWORD=${REGISTRY1_TOKEN:-}

 # debug print cli args
  echo "REGISTRY_URL: $REGISTRY_URL"
  echo "REGISTRY_USERNAME: $REGISTRY_USERNAME"

  echo "Creating $NAMESPACE namespace so that the docker-registry secret can be added first."
  kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
EOF

echo "Creating secret $FLUX_SECRET in namespace $NAMESPACE"
  kubectl create secret docker-registry "$FLUX_SECRET" -n $NAMESPACE \
    --docker-server="$REGISTRY_URL" \
    --docker-username="$REGISTRY_USERNAME" \
    --docker-password="$REGISTRY_PASSWORD" \
    --docker-email="$REGISTRY_EMAIL" \
    --dry-run=client -o yaml | kubectl apply -n $NAMESPACE -f -


kustomize build /flux . | kubectl apply -f -


# verify flux
#
kubectl wait --for=condition=available --timeout "${WAIT_TIMEOUT}s" -n $NAMESPACE "deployment/helm-controller"
kubectl wait --for=condition=available --timeout "${WAIT_TIMEOUT}s" -n $NAMESPACE "deployment/source-controller"
kubectl wait --for=condition=available --timeout "${WAIT_TIMEOUT}s" -n $NAMESPACE "deployment/kustomize-controller"
kubectl wait --for=condition=available --timeout "${WAIT_TIMEOUT}s" -n $NAMESPACE "deployment/notification-controller"



# echo installing metallb 

helm repo add metallb https://metallb.github.io/metallb
helm repo update
helm install metallb metallb/metallb --namespace metallb-system --create-namespace --wait

echo  configuring metallb IP address pools
kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.55.11.100-10.55.11.120 
EOF


kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: istio-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.55.11.130-10.55.11.150 
EOF

echo configuring metallb L2 advertisement
kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: metallb-l2-advert
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
  - istio-pool  
EOF



## Deploy bigbang


kustomize build  . | kubectl apply -f -