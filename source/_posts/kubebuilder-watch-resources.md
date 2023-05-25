---
title: Kubebuilder Watch Rresources
categories: 
  - Kubebuilder
tags:
  - k8s
sidebar: none 
---
我们在开发过程中，可能需要开发一个类似Deployment的资源逻辑，管理依赖资源是控制器的基础，如果不能观察它们的状态变化就不可能管理它们。这就意味着，我们需要 reconciler 能监控多个资源的变化。

> NOTE: Deployment 必须知道其管理的 ReplicaSet 何时更改，ReplicaSet 必须知道其管理的 Pod 何时被删除，或者从健康变为不健康等。

控制器运行时库为管理和监视资源提供了多种方式。这包括从简单而明显的用例（例如查看由控制器创建和管理的资源）到更独特和更高级的用例。

•控制器创建和管理的资源 (Watching Operator Managed Resources)
•外部管理的资源 (Watching Externally Managed Resources)

# 背景
以 Tcaplus 资源为例，Tcaplus 资源通过 ConfigMap（proto 文件）来创建表格。当 ConfigMap 发生变化时自动更新表格，下面例子不实际调用腾讯云API，只要验证接收到事件请求即可。

>NOTE: TcaplusDB 是腾讯出品的分布式NoSQL数据库。官方API文档：https://cloud.tencent.com/document/product/596/39648。

# 控制器创建和管理的资源
资源定义 (Defined Tcaplus Resources)
api/v1/tcaplus_types.go
```
type TcaplusSpec struct {
    Checksum string `json:"checksum,omitempty"`
    ConfigMapTemplate ConfigMapTemplate `json:"configMapTemplate,omitempty"`
}

type ConfigMapTemplate struct {
    Name string `json:"name,omitempty"`
    Data map[string]string `json:"data,omitempty"`
}
```
# 控制器逻辑 (Manage the Owned Resource)
## controllers/tcaplus_controller.go
当 tcaplus CR 创建时根据 ConfigMapTemplate 创建附属的 ConfigMap 资源并设置属主关系。

•Reconcile 方法：根据模版创建 ConfigMap 并设置属主关系
•SetupWithManager 方法：For 方法之后调用 Owns 方法
```
func (r *TcaplusReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	logger.Info("reconciling")
	tcaplus := &examplev1.Tcaplus{}
	if err := r.Get(ctx, req.NamespacedName, tcaplus); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	configMap := &corev1.ConfigMap{}
	configMap.Name = tcaplus.Spec.ConfigMapTemplate.Name
	configMap.Namespace = tcaplus.Namespace
	configMap.Data = tcaplus.Spec.ConfigMapTemplate.Data
    
	if err := controllerutil.SetControllerReference(tcaplus, configMap, r.Scheme); err != nil {
		logger.Error(err, "get configmap failed", "configmap", configMap.Name)
		return ctrl.Result{}, err
	}

	foundConfigMap := &corev1.ConfigMap{}
	err := r.Get(ctx, types.NamespacedName{Name: configMap.Name, Namespace: tcaplus.Namespace}, foundConfigMap)
	if err != nil && errors.IsNotFound(err) {
		logger.V(1).Info("creating configmap", "configmap", configMap.Name)
		err = r.Create(ctx, configMap)
	}
	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *TcaplusReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&examplev1.Tcaplus{}).
		Owns(&corev1.ConfigMap{}).
		Complete(r)
}
```

> NOTE：同一控制器创建的资源才可以设置属主关系，不然会提示：already owned by another controller。

# 测试
config/samples/example_v1_tcaplus.yaml
```
apiVersion: example.blazehu.com/v1
kind: Tcaplus
metadata:
  name: tcaplus-sample
spec:
  checksum: "123"
  configMapTemplate:
    name: "tcaplus-configmap-example"
    data:
      demo.proto: |
        syntax = "proto3";
        package example;
        message Example {
          uint32 a = 1;
          uint32 b = 2;
          uint32 c = 3;
        }
```
使用上述配置文件创建 tcaplus 资源。创建结果：
```
marklu-MB2:samples $ k get tcaplus
NAME AGE
tcaplus-sample 19m
marklu-MB2:samples $ k get configmap
NAME DATA AGE
tcaplus-configmap-example 1 19m
```
可以查看 tcaplus-configmap-example 的属主关系：
```
apiVersion: v1
data:
  demo.proto: |
    syntax = "proto3";
    package example;
    message Example {
      uint32 a = 1;
      uint32 b = 2;
    }
kind: ConfigMap
metadata:
  creationTimestamp: "2022-07-07T09:02:43Z"
  name: tcaplus-configmap-example
  namespace: default
  ownerReferences:
  - apiVersion: example.blazehu.com/v1
    blockOwnerDeletion: true
    controller: true
    kind: Tcaplus
    name: tcaplus-sample
    uid: 7c50f2e1-0e37-4aa0-bf49-c2d410d6153e
  resourceVersion: "6837330713"
  selfLink: /api/v1/namespaces/default/configmaps/tcaplus-configmap-example
  uid: 6c29f90b-0e51-4d9f-a6a8-cfb6906ed1b0
```
手动修改 tcaplus-sample 和 tcaplus-configmap-example 后查看控制器日志发现能正常观察 CR 和 ConfigMap 的变化了。

# 外部管理的资源
资源定义 (Defined Tcaplus Resources)
api/v1/tcaplus_types.go
```
type TcaplusSpec struct {
	Checksum     string             `json:"checksum,omitempty"`
	ConfigMapRef ConfigMapReference `json:"configMapRef,omitempty"`
}

type ConfigMapReference struct {
	Name string `json:"name,omitempty"`
}
```
# 控制器逻辑 (Manage the Owned Resource)
##### controllers/tcaplus_controller.go
For 方法之后调用 Watches 方法就可以监听对应资源的事件，但是会监听集群里所有相关资源的事件，所以这里我们自定义事件处理方法来过滤出我们关注的资源的事件。

•通过 EnqueueRequestsFromMapFunc 创建一个事件处理方法，该方法通过 FieldSelector 在 ConfigMap 的事件中过滤出跟 tcaplus CR 相关联的事件。
•使用 FieldSelector 时我们需要建立对应的索引，使用 mgr.GetFieldIndexer().IndexField() 创建。
```
const (
    ConfigMapField = ".spec.configMapRef.name"
) 
func (r *TcaplusReconciler) findObjectsForConfigMap(configMap client.Object) []reconcile.Request {
    attachedTcaplusList := &examplev1.TcaplusList{}
    listOps := &client.ListOptions{
        FieldSelector: fields.OneTermEqualSelector(ConfigMapField, configMap.GetName()),
        Namespace: configMap.GetNamespace(),
    }
    err := r.List(context.TODO(), attachedTcaplusList, listOps)
    if err != nil {
        return []reconcile.Request{}
    }
    requests := make([]reconcile.Request, len(attachedTcaplusList.Items))
    for i, item := range attachedTcaplusList.Items {
        requests[i] = reconcile.Request{
            NamespacedName: types.NamespacedName{
                Name: item.GetName(),
                Namespace: item.GetNamespace(),
            },
        }
    }
    return requests
} 

// SetupWithManager sets up the controller with the Manager.
func (r *TcaplusReconciler) SetupWithManager(mgr ctrl.Manager) error {
	if err := mgr.GetFieldIndexer().IndexField(context.Background(), &examplev1.Tcaplus{}, ConfigMapField, func(rawObj client.Object) []string {
		tcaplus := rawObj.(*examplev1.Tcaplus)
		if tcaplus.Spec.ConfigMapRef.Name == "" {
			return nil
		}
		return []string{tcaplus.Spec.ConfigMapRef.Name}
	}); err != nil {
		return err
	}

	return ctrl.NewControllerManagedBy(mgr).
		For(&examplev1.Tcaplus{}).
		Watches(
			&source.Kind{Type: &corev1.ConfigMap{}},
			handler.EnqueueRequestsFromMapFunc(r.findObjectsForConfigMap),
			builder.WithPredicates(predicate.ResourceVersionChangedPredicate{}),
		).
		Complete(r)
}
```
> NOTE: 我们也可以自己定一个变更过滤器 Predicate。也可以通过 WithEventFilter 来针对监听的所有资源过滤。
# 测试
config/samples/example_v1_tcaplus.yaml
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: tcaplus-configmap-example
data:
  demo.proto: |
    syntax = "proto3";
    package example;
    message Example {
      uint32 a = 1;
      uint32 b = 2;
      uint32 c = 3;
    }

---
apiVersion: example.blazehu.com/v1
kind: Tcaplus
metadata:
  name: tcaplus-sample
spec:
  checksum: "123"
  configMapRef:
    name: "tcaplus-configmap-example"
```

使用上述配置创建完毕后，手动修改 tcaplus-sample 和 tcaplus-configmap-example 查看控制器日志发现同样能正常观察 CR 和 ConfigMap 的变化。

> NOTE: 查看 tcaplus-configmap-example 可以看到没有和 tcaplus 的属主关系。

# 总结
•EventHandler 可以在 watch 特定资源时设置该资源的事件监听规则。
•WithEventFilter 配置变更过滤器，可以针对 watch 的所有资源，统一地设置事件监听规则。
•Owns 源码分析可以发现 Owns 相当于调用 Watches(&source.Kind{Type: <ForType-forInput>}, &handler.EnqueueRequestForOwner{OwnerType: apiType, IsController: true})。

# 参考文档
•https://www.kubebuilder.io/reference/watching-resources.html
•https://kubernetes.io/zh-cn/docs/concepts/overview/working-with-objects/owners-dependents/
•https://segmentfault.com/a/1190000020359577