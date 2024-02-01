---
title: Kubebuilder Admission Webhooks
categories: 
  - K8s
tags:
  - k8s
sidebar: none 
date: 2020-06-21
---
# 什么是准入控制?
准入控制（Admission Controller）是 Kubernetes API Server 用于拦截请求的一种手段。Admission 可以做到对请求的资源对象进行校验，修改。service mesh 最近很火的项目 Istio 天生支持 Kubernetes，利用的就是 Admission 对服务实例自动注入 sidecar。

# 什么是准入 Webhook？
准入 Webhook 是一种用于接收准入请求并对其进行处理的 HTTP 回调机制。 可以定义两种类型的准入 webhook，即 验证性质的准入 Webhook 和 修改性质的准入 Webhook。修改性质的准入 Webhook 会先被调用。它们可以更改发送到 API 服务器的对象以执行自定义的设置默认值操作。

在完成了所有对象修改并且 API 服务器也验证了所传入的对象之后， 验证性质的 Webhook 会被调用，并通过拒绝请求的方式来强制实施自定义的策略。

> 说明： 如果准入 Webhook 需要保证它们所看到的是对象的最终状态以实施某种策略。 则应使用验证性质的准入 Webhook，因为对象被修改性质 Webhook 看到之后仍然可能被修改。
![图片](/images/webhook1.jpeg)

# 尝试准入 Webhook
先决条件
•确保 Kubernetes 集群版本至少为 v1.16（以便使用 admissionregistration.k8s.io/v1 API） 或者 v1.9 （以便使 admissionregistration.k8s.io/v1beta1 API）。
•确保启用 MutatingAdmissionWebhook 和 ValidatingAdmissionWebhook 控制器。 这里是一组推荐的 admission 控制器，通常可以启用。
•确保启用了 admissionregistration.k8s.io/v1beta1 API。

# 配置准入 Webhook
你可以通过 ValidatingWebhookConfiguration 或者 MutatingWebhookConfiguration 动态配置哪些资源要被哪些准入 Webhook 处理。详细配置可以参阅 Webhook配置 部分。

# 认证和信任
默认情况下，apiserver不会向webhooks进行身份验证。但是，如果您想对客户端进行身份验证，可以将apiserver配置为使用基本身份验证、承载令牌或证书对Webhook进行身份验证。你可以在这里找到详细的步骤。

# 编写一个准入 Webhook 服务器
Webhook Admission 属于同步调用，需要用户部署自己的 webhook server，创建自定义的配置资源对象： ValidatingWebhookConfiguration 或 MutatingWebhookConfiguration。下面使用 kubebuilder 开发一个简单的 demo。

6.1 创建项目
```
kubebuilder init --domain marklu.com --owner "marklu" --repo marklu.com/kubegame
```

提示： 这里通过 kubebuilder v3 创建的话，在 config 目录下会缺少 certmanager、webhook 目录以及 default/manager_webhook_patch.yml 和 webhookcainjection_patch.yaml 文件。可以通过从v2生成拷贝过来进行修改。

6.2 创建控制器
这里只需要创建一个控制器
```
kubebuilder create api --group svc --version v1 --kind App
```
6.3 创建 webhook
Implement Your Handler
新增 mutatingwebhook.go & validatingwebhook.go 文件
```
// mutatingwebhook.go
package controllers

import (
	"context"
	"encoding/json"
	corev1 "k8s.io/api/core/v1"
	"net/http"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/webhook/admission"
)

// +kubebuilder:webhook:admissionReviewVersions=v1,sideEffects=None,path=/mutate-v1-svc,mutating=true,failurePolicy=fail,groups="",resources=services,verbs=create;update,versions=v1,name=msvc.kb.io

// KubeGameAnnotator annotates Pods
type KubeGameAnnotator struct {
	Client  client.Client
	decoder *admission.Decoder
}

// Handle adds an annotation to every incoming pods.
func (a *KubeGameAnnotator) Handle(ctx context.Context, req admission.Request) admission.Response {
	pod := &corev1.Pod{}

	err := a.decoder.Decode(req, pod)
	if err != nil {
		return admission.Errored(http.StatusBadRequest, err)
	}

	if pod.Annotations == nil {
		pod.Annotations = map[string]string{}
	}
	pod.Annotations["example-mutating-admission-webhook"] = "foo"

	marshaledPod, err := json.Marshal(pod)
	if err != nil {
		return admission.Errored(http.StatusInternalServerError, err)
	}

	return admission.PatchResponseFromRaw(req.Object.Raw, marshaledPod)
}

// KubeGameAnnotator implements admission.DecoderInjector.
// A decoder will be automatically injected.

// InjectDecoder injects the decoder.
func (a *KubeGameAnnotator) InjectDecoder(d *admission.Decoder) error {
	a.decoder = d
	return nil
}
```
```
// validatingwebhook.go
package controllers

import (
	"context"
	"fmt"
	corev1 "k8s.io/api/core/v1"
	"net/http"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/webhook/admission"
)

// +kubebuilder:webhook:admissionReviewVersions=v1,sideEffects=None,path=/validate-v1-svc,mutating=false,failurePolicy=fail,groups="",resources=services,verbs=create;update,versions=v1,name=vsvc.kb.io

// KubeGameValidator validates Pods
type KubeGameValidator struct {
	Client  client.Client
	decoder *admission.Decoder
}

// Handle admits a pod if a specific annotation exists.
func (v *KubeGameValidator) Handle(ctx context.Context, req admission.Request) admission.Response {
	pod := &corev1.Pod{}

	err := v.decoder.Decode(req, pod)
	if err != nil {
		return admission.Errored(http.StatusBadRequest, err)
	}

	key := "example-mutating-admission-webhook"
	anno, found := pod.Annotations[key]
	if !found {
		return admission.Denied(fmt.Sprintf("missing annotation %s", key))
	}
	if anno != "foo" {
		return admission.Denied(fmt.Sprintf("annotation %s did not have value %q", key, "foo"))
	}

	return admission.Allowed("")
}

// KubeGameValidator implements admission.DecoderInjector.
// A decoder will be automatically injected.

// InjectDecoder injects the decoder.
func (v *KubeGameValidator) InjectDecoder(d *admission.Decoder) error {
	v.decoder = d
	return nil
}
```
> 注意：因为上述逻辑需要services权限，所以我们在控制器里需要添加如下内容 //+kubebuilder:rbac:groups="",resources=services,verbs=get;list;watch;create;update;patch;delete 用于生成 rbac manifests。

> Register Your Handler
修改 main.go ，注册我们的 webhook handler
```
setupLog.Info("setting up webhook server")
hookServer := mgr.GetWebhookServer()

setupLog.Info("registering webhooks to the webhook server")
hookServer.Register("/mutate-v1-svc", &webhook.Admission{Handler: &controllers.KubeGameAnnotator{Client: mgr.GetClient()}})
hookServer.Register("/validate-v1-svc", &webhook.Admission{Handler: &controllers.KubeGameValidator{Client: mgr.GetClient()}})
```
> 提示： 这里注册的path（例如 validate-v1-sv）路径需要和 validatingwebhook.go 、mutatingwebhook.go 文件里的 CRD validation 匹配，不然 kustomize 生成出来的 webhook yaml 文件不对。

# 本地测试
make run 会报如下错误，是因为没有证书导致，需要配置证书，可以手动签发证书。
```
1.646924212701068e+09 ERROR setup problem running manager {"error": "open /var/folders/67/375276sx6hv0nln1whwm5syh0000gq/T/k8s-webhook-server/serving-certs/tls.crt: no such file or directory"}
```

我本地指定证书目录：
```
mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
		Scheme:                 scheme,
		MetricsBindAddress:     metricsAddr,
		Port:                   9443,
		HealthProbeBindAddress: probeAddr,
		LeaderElection:         enableLeaderElection,
		LeaderElectionID:       "27e1b0af.blazehu.com",
		CertDir:                "./cert/",
	})
```
重新启动发现恢复正常

> 提示： run controller-gen rbac:roleName=manager-role crd webhook paths=./... output:crd:artifacts:config=config/crd/bases -w to see all available markers, or controller-gen rbac:roleName=manager-role crd webhook paths=./... output:crd:artifacts:config=config/crd/bases -h for usage

# 7. 部署至集群
7.1 部署 cert manager
建议使用 certmanager 为 webhook 服务器提供证书。其他解决方案也有效，只要它们将证书放在所需的位置。安装文档点这里
通过如下方式注入 caBundle :
```
# This patch add annotation to admission webhook config and
# the variables $(CERTIFICATE_NAMESPACE) and $(CERTIFICATE_NAME) will be substituted by kustomize.
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: mutating-webhook-configuration
  annotations:
    cert-manager.io/inject-ca-from: $(CERTIFICATE_NAMESPACE)/$(CERTIFICATE_NAME)
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: validating-webhook-configuration
  annotations:
    cert-manager.io/inject-ca-from: $(CERTIFICATE_NAMESPACE)/$(CERTIFICATE_NAME)
```
# 7.2 构建镜像
•镜像替换：default/manager_auth_proxy_patch.yaml 文件中的 gcr.io/kubebuilder/kube-rbac-proxy:v0.8.0 （网络慢）
•Dockerfile 去掉 go mod download，直接使用本地 vendor 构建 （网络慢）
•Dockerfile 去掉 COPY api/ api/， 因为没有创建 Resource
•去掉 main.go 文件中配置的证书路径
```
make docker-build IMG=xxxx
make docker-push IMG=xxxx
```
# 7.3 修改模版，然后部署
•修改 config/default/kustomization.yaml ， 将 webhook、certmanager 相关的注释去掉。
•修改 config/crd/kustomization.yaml ，将 webhook、certmanager 相关的注释去掉。
•修改 config/default/kustomization.yaml ， 将 crd 相关的给注释掉。
```
make deploy IMG=xxxx
```
部署成功：

查看控制器日志：

# 7.4 测试
简单创建一个 service，webhook 会注入一个注解，并进行验证。下图可以看到成功注入。


控制日志：

说明：查看 MutatingWebhookConfiguration 配置可以看到 caBundle 被注入其中了。

# 8. 总结
总结下 webhook Admission 的优势：

•webhook 可动态扩展 Admission 能力，满足自定义客户的需求。
•不需要重启 API Server，可通过创建 webhook configuration 热加载 webhook admission。

Reference documentation
•https://kubernetes.io/zh/docs/reference/access-authn-authz/extensible-admission-controllers
•https://kubernetes.io/zh/docs/tasks/tls/managing-tls-in-a-cluster/
•https://book.kubebuilder.io/reference/admission-webhook.html
•https://github.com/kubernetes-sigs/controller-runtime/tree/master/examples/builtins