---
title: ArgoCD
categories:
  - gitops
tags:
  - gitops
sidebar: none 
date: 2021-01-21 
---
# Argo CD 能落地 GitOps
Argo CD 是以 Kubernetes 为基础设施的 GitOps 持续部署工具。下面是来自 Argo CD 社区的原理图：
![gitops](/images/gitops.png)
>
# 强大而易扩展的 Argo CD
对于一般的 Kubernetes 运维场景，上面描述的功能是够用的。但是如果是复杂场景，涉及多云、多平台、多中间件，也是需要考虑的。
![argocd](/images/argocd.png)
# 安装
在 Kubernetes 上部署 Argo CD
新建命名空间，部署 Argo CD

这里选择当前发布的最新版本: 1.8.3
```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v1.8.3/manifests/install.yaml
```
Argo CD 社区还提供了 HA 模式的部署方式，kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v1.8.3/manifests/ha/install.yaml 用于生产环境。

### 查看服务
```
kubectl -n argocd get svc

NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
argocd-dex-server       ClusterIP   10.233.34.191   <none>        5556/TCP,5557/TCP,5558/TCP   5m37s
argocd-metrics          ClusterIP   10.233.54.3     <none>        8082/TCP                     5m36s
argocd-redis            ClusterIP   10.233.18.86    <none>        6379/TCP                     5m36s
argocd-repo-server      ClusterIP   10.233.3.171    <none>        8081/TCP,8084/TCP            5m36s
argocd-server           NodePort    10.233.61.3     223.*.*.*       80:31808/TCP,443:30992/TCP   5m36s
argocd-server-metrics   ClusterIP   10.233.36.228   <none>        8083/TCP                     5m36s
```

### 查看 admin 账户密码
```
$ kc get secret -n argocd 
NAME                                           TYPE                                  DATA   AGE
argocd-application-controller-token-w2gdp      kubernetes.io/service-account-token   3      182d
argocd-applicationset-controller-token-q444h   kubernetes.io/service-account-token   3      182d
argocd-dex-server-token-mwfjf                  kubernetes.io/service-account-token   3      182d
argocd-initial-admin-secret                    Opaque                                1      182d
argocd-notifications-controller-token-m4ctr    kubernetes.io/service-account-token   3      182d
argocd-notifications-secret                    Opaque                                0      182d
argocd-redis-token-pqx42                       kubernetes.io/service-account-token   3      182d
argocd-repo-server-token-zwnpz                 kubernetes.io/service-account-token   3      182d
argocd-secret                                  Opaque                                9      182d
argocd-server-token-cpv7l                      kubernetes.io/service-account-token   3      182d
default-token-5vdwr                            kubernetes.io/service-account-token   3      182d
repo-4178615321                                Opaque                                6      177d
sh-gitops                                      kubernetes.io/dockercfg               1      180d

$ kc get secret -n argocd  -o yaml argocd-initial-admin-secret 
echo 'bkFFMElSbMFR1dnBiRA=='|base64 -d

```
### 访问页面
浏览器中打开https://223.*.*.*/login (223.*.*.*不是真实ip,替换成您的ip)
