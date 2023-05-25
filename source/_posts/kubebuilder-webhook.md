---
title: Kubebuilder Webhook 开发之创建 TLS 证书
---
Kubebuilder Webhook 开发之创建 TLS 证书
在编写一个准入 Webhook 服务时，需要配置相关证书，k8s 提供了 api 用于对用户自主创建的证书进行认证签发。以下部分演示为 Webhook 服务创建 TLS 证书。

创建 TLS 证书
创建你的证书
通过运行以下命令生成私钥:

cat <<EOF | cfssl genkey - | cfssljson -bare server
{
"hosts": [
"my-svc.my-namespace.svc.cluster.local",
"my-pod.my-namespace.pod.cluster.local",
"192.0.2.24",
"10.0.34.2"
],
"CN": "my-pod.my-namespace.pod.cluster.local",
"key": {
"algo": "ecdsa",
"size": 256
}
}
EOF

此命令生成两个文件；它生成包含 PEM 编码 PKCS#10 证书请求的 server.csr， 以及 PEM 编码密钥的 server-key.pem，用于待生成的证书。

创建证书签名请求（CSR）
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
name: example
spec:
request: $(cat server.csr | base64 | tr -d '\n')
usages:

•digital signature
•key encipherment
•server auth
EOF

你能看到的输出类似于：

certificatesigningrequest.certificates.k8s.io/example created

Warning: certificates.k8s.io/v1beta1 CertificateSigningRequest is deprecated in v1.19+, unavailable in v1.22+; use certificates.k8s.io/v1 CertificateSigningRequest

CSR 处于 Pending 状态。执行下面的命令你将可以看到：

kubectl get csr

NAME AGE SIGNERNAME REQUESTOR CONDITION
example 17s kubernetes.io/legacy-unknown 100015926370-1650441195 Pending

批准证书签名请求（CSR）
kubectl certificate approve example

certificatesigningrequest.certificates.k8s.io/example approved

你现在应该能看到如下输出：

kubectl get csr

NAME AGE SIGNERNAME REQUESTOR CONDITION
example 5m4s kubernetes.io/legacy-unknown 100015926370-1650441195 Approved,Issued

下载证书并使用它
kubectl get csr example -o jsonpath='{.status.certificate}' | base64 --decode > server.crt

现在你可以将 server.crt 和 server-key.pem 作为你的服务的 https 认证了。

例如 kubebuilder 中使用 TLS 证书，将 server.crt 和 server-key.pem 放在 cert 目录中并修改名称为 tls.crt 和 tls.key，然后指定证书目录：

mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
Scheme: scheme,
MetricsBindAddress: metricsAddr,
Port: 9443,
HealthProbeBindAddress: probeAddr,
LeaderElection: enableLeaderElection,
LeaderElectionID: "27e1b0af.marklu.com",
CertDir: "./cert/",
})

从 v1beta1 迁移到 v1
上述例子使用 certificates.k8s.io/v1beta1 API 版本的 CertificateSigningRequest 不在 v1.22 版本中继续提供。官方迁移指南点这里。 我们可以使用 certificates.k8s.io/v1 API 版本，此 API 从 v1.19 版本开始可用。

•certificates.k8s.io/v1 中需要额外注意的变更：
•对于请求证书的 API 客户端而言：
•spec.signerName 现在变成必需字段（参阅 已知的 Kubernetes 签署者）， 并且通过 certificates.k8s.io/v1 API 不可以创建签署者为 kubernetes.io/legacy-unknown 的请求
•spec.usages 现在变成必需字段，其中不可以包含重复的字符串值， 并且只能包含已知的用法字符串

创建你的证书
通过运行以下命令生成私钥:

cat <<EOF | cfssl genkey - | cfssljson -bare server
{
"hosts": [
"my-svc.my-namespace.svc.cluster.local",
"my-pod.my-namespace.pod.cluster.local",
"192.0.2.24",
"10.0.34.2"
],
"CN": "my-pod.my-namespace.pod.cluster.local",
"key": {
"algo": "ecdsa",
"size": 256
}
}
EOF

创建证书签名请求（CSR）
这里 csr signerName 不能是 kubernetes.io/legacy-unknown，演示我们随便指定一个为 example.com/serving，v1beta1 版本默认是 kubernetes.io/legacy-unknown。

cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
name: example
spec:
request: $(cat server.csr | base64 | tr -d '\n')
signerName: example.com/serving
usages:

•digital signature
•key encipherment
•server auth
EOF

批准证书签名请求（CSR）
kubectl certificate approve example

certificatesigningrequest.certificates.k8s.io/example approved

你现在应该能看到如下输出：

kubectl get csr

NAME AGE SIGNERNAME REQUESTOR CONDITION
example 11s example.com/serving 100015926370-1650441195 Approved

这里可以看到证书请求已被批准，但是没有自动签名，正在等待请求的签名者对其签名。

签名证书签名请求（CSR）
我们扮演证书签署者的角色，颁发证书并将其上传到 API 服务器。

创建证书颁发机构
通过运行以下命令创建签名证书:

cat <<EOF | cfssl gencert -initca - | cfssljson -bare ca
{
"CN": "example.com/serving",
"key": {
"algo": "rsa",
"size": 2048
}
}
EOF

这会产生一个证书颁发机构密钥文件（ca-key.pem）和证书（ca.pem）。

颁发证书
创建文件 server-signing-config.json 内容如下：

{
"signing": {
"default": {
"usages": [
"digital signature",
"key encipherment",
"server auth"
],
"expiry": "876000h",
"ca_constraint": {
"is_ca": false
}
}
}
}

使用 server-signing-config.json 签名配置、证书颁发机构密钥文件和证书来签署证书请求：

kubectl get csr example -o jsonpath='{.spec.request}' | \
base64 --decode | \
cfssl sign -ca ca.pem -ca-key ca-key.pem -config server-signing-config.json - | \
cfssljson -bare ca-signed-server

这会生成一个签名的服务证书文件，ca-signed-server.pem。

上传签名证书
kubectl get csr example -o json | \
jq '.status.certificate = "'$(base64 ca-signed-server.pem | tr -d '\n')'"' | \
kubectl replace --raw /apis/certificates.k8s.io/v1/certificatesigningrequests/example/status -f -

批准 CSR 并上传签名证书后，你现在应该能看到如下输出：

kubectl get csr

NAME AGE SIGNERNAME REQUESTOR CONDITION
example 10m example.com/serving 100015926370-1650441195 Approved,Issued

这是你可以正常下载证书并使用它了。

参考文档
•https://kubernetes.io/zh-cn/docs/reference/access-authn-authz/certificate-signing-requests/
•https://kubernetes.io/zh-cn/docs/tasks/tls/managing-tls-in-a-cluster/#configuring-your-cluster-to-provide-signing
•https://kubernetes.io/zh-cn/docs/reference/using-api/deprecation-guide/