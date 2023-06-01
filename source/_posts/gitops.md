---
title: GitOps
categories:
  - gitops
tags:
  - gitops
sidebar: none 
date: 2021-01-21 
---
# 管理员密码
```
admin管理员的密码可以通过命令获取：
ARGO_PWD=`kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d` 
```

# 用户管理
```
kubectl edit cm argocd-rbac-cm -n argocd
apiVersion: v1
data:
  accounts.tom: apiKey,login
  accounts.tom.enabled: "true"
  accounts.lele: apiKey,login
  accounts.lele.enabled: "true"
```

## 生成密码
```
argocd account update-password --account tom --new-password 12345678 --current-password $ARGO_PWD
或者
argocd account update-password --account tom --new-password 12345678
输入admin的密码
```

## 命令行登录
argocd login 10.100.16.250:8080 --username tom --password 1234 --insecure

## 命令行登出
argocd logout 10.100.16.250:8080

## 权限控制
用户权限控制：修改cm下的argocd-rbac-cm
```
data:
   policy.csv: |
    p, role:gitops, applications, get, *, allow
    p, role:gitops, applications, create, *, allow
    p, role:gitops, applications, update, *, allow
    p, role:gitops, applications, sync, *, allow
    p, role:gitops, applications, override, *, allow
    p, role:gitops, repositories, get, *, allow
    p, role:gitops, repositories, create, *, allow
    p, role:gitops, repositories, update, *, allow
    p, role:gitops, projects, create, *, allow
    p, role:gitops, projects, get, *, allow
    p, role:gitops, clusters, get, *, allow
    p, role:gitops, clusters, list, *, allow
    g, tom, role:gitops
 apiVersion: v1
 kind: ConfigMap
 metadata:
   labels:
     app.kubernetes.io/name: argocd-rbac-cm
     app.kubernetes.io/part-of: argocd
   name: argocd-rbac-cm
   namespace: argocd
```
注意：必须增加 g, tom, role:gitops 将 tom 用户加到 gitops 这个 role 中。


# 生成token
```
export ARGOCD_SERVER=10.100.16.250:8080
wget http://${ARGOCD_SERVER}/download/argocd-linux-amd64 --no-check-certificate
mv argocd-linux-amd64 /usr/local/bin/argocd
chmod 751 /usr/local/bin/argocd
argocd login 10.100.16.250:8080
argocd_api_token=`argocd account generate-token -a cnc-api` // token可以在web控制台生成
export ARGOCD_AUTH_TOKEN=${argocd_api_token}
```

# 同步application，如果没有禁用tls，就不需要加--insecure  |--plaintext  
```
argocd app sync apps --auth-token $ARGOCD_AUTH_TOKEN --server 10.100.16.250:8080 --insecure   
argocd app wait apps --auth-token $ARGOCD_AUTH_TOKEN --server 10.100.16.250:8080 --insecure   
```

# 状态
OutOfSync：已经部署的应用程序的实际状态与目标状态有差异，则被认为是 OutOfSync 状态

# web-base-terminal
```
Enabling the terminal¶
Set the exec.enabled key to "true" on the argocd-cm ConfigMap.

Patch the argocd-server Role (if using namespaced Argo) or ClusterRole (if using clustered Argo) to allow argocd-server to exec into pods
- apiGroups:
  - ""
  resources:
  - pods/exec
  verbs:
  - create
Add RBAC rules to allow your users to create the exec resource, i.e.

p, role:myrole, exec, create, */*, allow
```

# webhook,git提交后立即触发argocd sync ,触发webhook需要添加argocd接口白名单，还是得用gitlab
```
1. gitlab/github 配置webhook 
http://10.100.16.250:8080/api/webhook
application/json
test666
2. echo test666 |base64 -w 0
WW9sdfyaGE2NjY4OD
3. kubectl edit secret argocd-secret -n argocd 
stringData:
  # github webhook secret
  webhook.github.secret:  WW9sdfyaGE2NjY4OD
```


# 健康检查
```
$ kc get configmap -n argocd argocd-cm -o yaml              
apiVersion: v1
data:
  accounts.cnc-api: apiKey
  accounts.cnc-api.enabled: "true"
  exec.enabled: "true"
  resource.customizations.health.apps.kruise.io_SidecarSet: |
    hs = {}
    -- if paused
    if obj.spec.updateStrategy.paused then
      hs.status = "Suspended"
      hs.message = "SidecarSet is Suspended"
      return hs
    end

    -- check sidecarSet status
    if obj.status ~= nil then
      if obj.status.observedGeneration < obj.metadata.generation then
        hs.status = "Progressing"
        hs.message = "Waiting for rollout to finish: observed sidecarSet generation less then desired generation"
        return hs
      end

      if obj.status.matchedPods == 0 then
        hs.status = "Healthy"
        return hs
      end

      if obj.status.updatedPods ~= obj.status.matchedPods then
        hs.status = "Progressing"
        hs.message = "Waiting for rollout to finish: replicas hasn't finished updating..."
        return hs
      end

      if obj.status.readyPods ~= obj.status.matchedPods then
        hs.status = "Progressing"
        hs.message = "Waiting for rollout to finish: replicas hasn't finished updating..."
        return hs
      end

      hs.status = "Healthy"
      return hs
    end

    -- if status == nil
    hs.status = "Progressing"
    hs.message = "Waiting for sidecarSet"
    return hs
  resource.customizations.health.argoproj.io_Application: |
    hs = {}
    hs.status = "Progressing"
    hs.message = ""
    if obj.status ~= nil then
      if obj.status.health ~= nil then
        hs.status = obj.status.health.status
        if obj.status.health.message ~= nil then
          hs.message = obj.status.health.message
        end
      end
    end
    return hs
  resource.customizations.health.kubegame.tencent.com_Tcaplus: |
    hs = {}
    if obj.status ~= nil then
      if obj.status.status == "Complete" then
        hs.status = "Healthy"
        hs.message = obj.status.tableInfo
        return hs
      end
    end
    hs.status = "Progressing"
    hs.message = "Waiting for tcaplus"
    return hs
  resource.customizations.knownTypeFields.tkex.tencent.com_GameDeployment: |
    - field: spec.template.spec
      type: core/v1/PodSpec
  resource.customizations.knownTypeFields.tkex.tencent.com_GameStatefulSet: |
    - field: spec.template.spec
      type: core/v1/PodSpec
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
  name: argocd-cm
  namespace: argocd
```