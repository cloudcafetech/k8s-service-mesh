## Kuma Version Routing

Deploy kuma trafficroute as below for Bookinfo application.

```
apiVersion: kuma.io/v1alpha1
kind: TrafficRoute
mesh: default
metadata: 
  name: productpage-review
spec: 
  sources: 
    - match: 
        kuma.io/service: '*'
  destinations: 
    - match: 
        kuma.io/service: reviews_sample_svc_9080
  conf: 
    loadBalancer: 
      roundRobin: 
    split: 
    - weight: 100
      destination: 
        kuma.io/service: reviews_sample_svc_9080
        kuma.io/zone: dev
        version: v1
    http: 
      - match: 
          headers: 
            end-user: 
              exact: "pkar"
        split: 
          - weight: 50
            destination: 
              kuma.io/service: reviews_sample_svc_9080
              kuma.io/zone: stage
              version: v3
          - weight: 50
            destination: 
              kuma.io/service: reviews_sample_svc_9080
              kuma.io/zone: stage
              version: v2 

```
