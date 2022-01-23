#!/bin/bash
# Istio Multi Cluster Setup on Kubernetes

ISTIO_VER=1.10.1

CLUSTER1_PATH=
CLUSTER2_PATH=

ENV1=dev
ENV2=stage

red=$(tput setaf 1)
grn=$(tput setaf 2)
yel=$(tput setaf 3)
blu=$(tput setaf 4)
bld=$(tput bold)
nor=$(tput sgr0)

# Install Istioctl
toolistio() {
 echo "$bld$grn Installing Istioctl $nor"
 curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VER sh -
 sudo rm /usr/local/bin/istioctl
 sudo cp `pwd`/istio-$ISTIO_VER/bin/istioctl /usr/local/bin/istioctl
 yum install -y make
}

# Merge Multi Cluster Kubeconfig
mergeconfig() {

 export KUBECONFIG=$CLUSTER1_PATH:$CLUSTER2_PATH
 kubectl config view
 kubectl config view --raw > merge-config
 export KUBECONFIG=~/merge-config
 kubectl config rename-context `more $CLUSTER1_PATH | grep current-context | cut -d: -f2 | tr -d '"' | tr -d ' '` $ENV1
 kubectl config rename-context `more $CLUSTER2_PATH | grep current-context | cut -d: -f2 | tr -d '"' | tr -d ' '` $ENV2
 kubectl config get-contexts

}

# Create Common Root CA and intermediate CA for All Clusters
createcerts() {

 mkdir -p certs
 cd certs
 export KUBECONFIG=~/merge-config
 make -f ~/istio-$ISTIO_VER/tools/certs/Makefile.selfsigned.mk root-ca
 for ctx in $ENV1 $ENV2; do
  echo -e "Creating and applying CA certs for $ctx .........\n"
  make -f ~/istio-$ISTIO_VER/tools/certs/Makefile.selfsigned.mk $ctx-cacerts 
  kubectl create namespace istio-system --context $ctx 
  kubectl create secret generic cacerts -n istio-system \
   --from-file=$ctx/ca-cert.pem \
   --from-file=$ctx/ca-key.pem \
   --from-file=$ctx/root-cert.pem \
   --from-file=$ctx/cert-chain.pem \
   --context=$ctx
  echo -e "-------------\n"
 done

}

# Install Istio on Multi Primary Clusters
istiosetup() {

 mkdir multi-cluster
 export KUBECONFIG=~/merge-config

 for ctx in $ENV1 $ENV2; do
 echo -e "Configure $ctx-cluster as a primary .........\n"

cat <<EOF > multi-cluster/$ctx-cluster.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: $ctx-cluster
      network: $ctx-network
EOF
 
  istioctl install --context=$ctx -f multi-cluster/$ctx-cluster.yaml

  echo -e "-------------\n"
  echo -e "Install the $ENV1-$ENV2 gateway in $ctx-cluster .........\n"

  ~/istio-$ISTIO_VER/samples/multicluster/gen-eastwest-gateway.sh --mesh mesh1 --cluster $ctx-cluster --network $ctx-network | istioctl --context=$ctx install -y -f -
  
  echo -e "-------------\n"
  echo -e "Expose services in $ctx-cluster .........\n"

  kubectl --context $ctx apply -n istio-system -f ~/istio-$ISTIO_VER/samples/multicluster/expose-services.yaml

  echo -e "-------------\n"
  done

  for r1 in $ENV1 $ENV2; do
   for r2 in $ENV1 $ENV2; do
    if [[ "${r1}" == "${r2}" ]]; then continue; fi
     echo -e "Enable Endpoint Discovery of ${r1} in ${r2} .........\n"
     istioctl x create-remote-secret --context ${r1} --name ${r1}-cluster --namespace istio-system | kubectl apply -f - --context ${r2}
     echo -e "-------------\n"
   done
  done

 for ctx in $ENV1 $ENV2; do
  echo -e "PODs in istio-system from ${ctx} .........\n"
   kubectl get pods -n istio-system --context $ctx
   echo -e "-------------\n"
 done

}

# Setup Monitoring on Multiple Clusters
setupmon() {

  for ctx in $ENV1 $ENV2; do
    echo -e "Install Prometheus & Kiali in $ctx .........\n"
    kubectl apply -f ~/istio-$ISTIO_VER/samples/addons/prometheus.yaml --context $ctx
    kubectl apply -f ~/istio-$ISTIO_VER/samples/addons/kiali.yaml --context $ctx
    echo -e "-------------\n"
  done

}

# Setup ALL Istio on Multiple Clusters
setupall() {

 toolistio
 mergeconfig
 createcerts
 istiosetup
 setupmon

}

# Uninstall Istio From All Clusters
uninstallistio() {

 for ctx in $ENV1 $ENV2; do

  echo -e "Removing Istio from $ctx .........\n"
  istioctl x uninstall --purge -y --context $ctx
  echo -e "-------------\n"
 
  echo -e "Delete Prometheus and Kiali from $ctx .........\n"
  kubectl delete -f ~/istio-$ISTIO_VER/samples/addons/prometheus.yaml --context $ctx
  kubectl delete -f ~/istio-$ISTIO_VER/samples/addons/kiali.yaml --context $ctx
  echo -e "-------------\n"
 
  echo -e "Delete namespace from $ctx .........\n"
  kubectl delete namespace istio-system --context $ctx
  echo -e "-------------\n"
  
 done

}

case "$1" in
    'toolistio')
            toolistio
            ;;
    'mergeconfig')
            mergeconfig
            ;;
    'createcerts')
            createcerts
            ;;
    'istiosetup')
            istiosetup
            ;;
    'setupmon')
            setupmon
            ;;
    'setupall')
            setupall
            ;;
    'uninstallistio')
            uninstallistio
            ;;
    *)
            echo
            echo "$bld$grn Usage: $0 { toolistio | mergeconfig | createcerts | istiosetup | setupmon | setupall | uninstallistio } $nor"
            echo
            exit 1
            ;;
esac

exit 0
