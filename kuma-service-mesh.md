## KUMA Service Mesh Setup

Kuma is a platform agnostic open-source control plane for service mesh and microservices management, with support for Kubernetes, VM, and bare metal environments.

### Kuma Multi Cluster (multi-zone) deployment

Kuma global zone sync (kuma-global-zone-sync) service works in Layer 4 **[ISSUE](https://github.com/kumahq/kuma/issues/3724#issuecomment-1016244530)** and ingress does not support TCP or UDP services.
To make it work we have to use the flags --tcp-services-configmap and --udp-services-configmap in ingress controller to point to an existing config map.
Where the key is the external port to use and the value indicates the service to expose using the format: <namespace/service name>:<service port>:[PROXY]:[PROXY].
        
[Ref#1](https://kubernetes.github.io/ingress-nginx/user-guide/exposing-tcp-udp-services/)  

[Ref#2](https://stackoverflow.com/questions/61430311/exposing-multiple-tcp-udp-services-using-a-single-loadbalancer-on-k8s/61461960#61461960)          

- Modify existing ingress controller as below or [Setup Nginx Controller using yaml](./kube-nginx-ingress-kuma.yaml)
        
```
kubectl create configmap tcp-services -n kube-router
kubectl create configmap udp-services -n kube-router
kubectl patch configmap tcp-services -n kube-router --patch '{"data":{"5685":"kuma-system/kuma-global-zone-sync:5685"}}'
kubectl get configmap tcp-services -n kube-router -o yaml
```

Edit ingress-nginx-controller deployment

```kubectl edit deployments -n kube-router ingress-nginx-controller``` and add following in ```args``` sections

```
        - --tcp-services-configmap=$(POD_NAMESPACE)/tcp-services
        - --udp-services-configmap=$(POD_NAMESPACE)/udp-services
```

and add following in ```port``` sections

```
        - containerPort: 5685                                                                                                     
          hostPort: 5685                                                                                                          
          name: kuma                                                                                                              
          protocol: TCP 
```

Edit ingress-nginx-controller service

```kubectl edit svc -n kube-router ingress-nginx-controller``` and add following in ```ports``` sections

```
  - name: kuma                                                                            
    port: 5685                               
    protocol: TCP                            
    targetPort: kuma
```

Now verify both service and deployment

```
kubectl get svc -n kube-router ingress-nginx-controller
kubectl get deployments -n kube-router ingress-nginx-controller
```

- Install Kuma Tools as root
        
```
curl -L https://kuma.io/installer.sh | sh -
cd kuma-1.4.1/bin
ln -s /root/kuma-1.4.1/bin/kumactl /usr/local/bin/kumactl
```        
        
- Install Kuma in Central Cluster (Global Zone) 

```
kumactl install control-plane --mode=global | kubectl apply -f -
kubectl wait -n kuma-system --timeout=90s --for condition=Ready --all pods
kubectl get pod -n kuma-system
```

- Create Ingress for kuma 

```
cat > kumaing.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: nginx
  name: kuma-global-zone
  namespace: kuma-system
spec:
  rules:
  - host: kumagz.172.26.32.56.nip.io
    http:
      paths:
      - backend:
          service:
            name: kuma-global-zone-sync
            port:
              number: 5685
        path: /
        pathType: Prefix
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: nginx
  name: kumagui
  namespace: kuma-system
spec:
  rules:
  - host: kumagui.172.26.32.56.nip.io
    http:
      paths:
      - backend:
          service:
            name: kuma-control-plane
            port:
              number: 5681
        path: /
        pathType: Prefix
EOF        
```

- Install Kuma in Remote Cluster (Dev Zone)

```
kumactl install control-plane --mode=zone --zone=dev --ingress-enabled --kds-global-address grpcs://kumagz.172.26.32.56.nip.io:5685 | kubectl apply -f -
kubectl wait -n kuma-system --timeout=90s --for condition=Ready --all pods
kubectl get pod -n kuma-system
```
        
- Install Kuma in Remote Cluster (Stage Zone)

```
kumactl install control-plane --mode=zone --zone=stage --ingress-enabled --kds-global-address grpcs://kumagz.172.26.32.56.nip.io:5685 | kubectl apply -f -
kubectl wait -n kuma-system --timeout=90s --for condition=Ready --all pods
kubectl get pod -n kuma-system
```        
