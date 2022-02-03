## Setup for Version Routing


### Create Gateway, DestinationRule & VirtualService

```
export KUBECONFIG=~/merge-config
export ENV1=dev
export ENV2=stage

kubectl apply --context=$ENV1 -f ~/istio-1.10.1/samples/bookinfo/networking/bookinfo-gateway.yaml -n sample
kubectl apply --context=$ENV1 -f gw-ing.yaml

kubectl apply --context=$ENV1 -n sample -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: reviews-destination
spec:
  host: reviews
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  - name: v3
    labels:
      version: v3
EOF

kubectl apply --context=$ENV2 -n sample -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: reviews-destination
spec:
  host: reviews
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  - name: v3
    labels:
      version: v3
EOF

kubectl --context=$ENV1 -n sample apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews-route
spec:
  hosts:
  - reviews
  http:
  - match:
    - headers:
        end-user:
          exact: pkar
    route:
    - destination:
        host: reviews
        subset: v2
      weight: 50
    - destination:
        host: reviews
        subset: v3
      weight: 50
  - route:
    - destination:
        host: reviews
        subset: v1
EOF
```

### Delete DestinationRule & VirtualService

```
#kubectl delete vs reviews-route -n sample --context=dev
#kubectl delete dr reviews-destination -n sample --context=dev
#kubectl delete dr reviews-destination -n sample --context=stage
```
