---
title: Kubebuilder Best Practices
---
Kubebuilder is a framework for building Kubernetes APIs using custom resource definitions (CRDs).
> Note: kubebuilder can save us a lot of work and make developing CRDs and adminsion webhooks incredibly easy.
# Installation
```
# download kubebuilder and install locally.
curl -L -o kubebuilder https://go.kubebuilder.io/dl/latest/$(go env GOOS)/$(go env GOARCH)
chmod +x kubebuilder && mv kubebuilder /usr/local/bin/
```
# Create a Project 
> Create a directory, and then run the init command inside of it to initialize a new project. Follows an example.
```
[marklu@MacBook ~]$ mkdir ~/Project/workspace-go/example
[marklu@MacBook ~]$ cd ~/Project/workspace-go/example
[marklu@MacBook ~]$ kubebuilder init --domain marklu.com --owner "marklu" --repo marklu.com/example
Writing kustomize manifests for you to edit...
Writing scaffold for you to edit...
Get controller runtime:
$ go get sigs.k8s.io/controller-runtime@v0.10.0
Update dependencies:
$ go mod tidy
Next: define a resource with:
$ kubebuilder create api
```
> If your project is initialized within GOPATH, the implicitly called go mod init will interpolate the module path for you. Otherwise –repo=must be set.

# Adding a new API
```
[marklu@MacBook ~]$ kubebuilder create api --group cos --version v1 --kind Bucket
Create Resource [y/n]
y
Create Controller [y/n]
y
Writing kustomize manifests for you to edit...
Writing scaffold for you to edit...
api/v1/bucket_types.go
controllers/bucket_controller.go
Update dependencies:
$ go mod tidy
Running make:
$ make generate
go: creating new go.mod: module tmp
Downloading sigs.k8s.io/controller-tools/cmd/controller-gen@v0.7.0
go get: added sigs.k8s.io/controller-tools v0.7.0
/Users/huyuhan/Project/workspace-go/example/bin/controller-gen object:headerFile="hack/boilerplate.go.txt" paths="./..."
Next: implement your new API and generate the manifests (e.g. CRDs,CRs) with:
$ make manifests
```

# Designing an API
> api/v1/bucket_types.go
```
// BucketSpec defines the desired state of Bucket
type BucketSpec struct {
	// INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	// Foo is an example field of Bucket. Edit bucket_types.go to remove/update
	Name   string `json:"name,omitempty"`
	Region string `json:"region,omitempty"`
	ACL    string `json:"acl,omitempty"`
}
```

# Implementing a controller
>controllers/cos.go 
```
package controllers

import (
	"context"
	"fmt"
	"github.com/tencentyun/cos-go-sdk-v5"
	"net/http"
	"net/url"
)

type CosStorage struct {
	client          *cos.Client
	accessKeyId     string
	accessKeySecret string
	bucket          string
	region          string
}

// NewCosStorage endpoint: https://cloud.tencent.com/document/product/436/6224
func NewCosStorage(region, bucketName string) *CosStorage {
	url, _ := url.Parse(fmt.Sprintf("https://%s.cos.%s.myqcloud.com", bucketName, region))
	accessKeyId := ""
	accessKeySecret := ""
	b := &cos.BaseURL{BucketURL: url}
	client := cos.NewClient(b, &http.Client{
		Transport: &cos.AuthorizationTransport{
			SecretID:  accessKeyId,
			SecretKey: accessKeySecret,
		},
	})
	return &CosStorage{
		client:          client,
		accessKeyId:     accessKeyId,
		accessKeySecret: accessKeySecret,
		region:          region,
		bucket:          bucketName,
	}
}

func (c *CosStorage) Put(acl string) error {
	opt := &cos.BucketPutOptions{
		XCosACL: acl,
	}
	_, err := c.client.Bucket.Put(context.Background(), opt)
	return err
}

func (c *CosStorage) Delete() error {
	_, err := c.client.Bucket.Delete(context.Background())
	return err
}
```
controllers/bucket_controller.go
> tips: Finalizers allow controllers to implement asynchronous pre-delete hooks. Let’s say you create an external resource (such as a storage bucket) for each object of your API type, and you want to delete the associated external resource on object’s deletion from Kubernetes, you can use a finalizer to do that.
```
/*
Copyright 2022 marklu.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controllers

import (
	"context"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
	"sigs.k8s.io/controller-runtime/pkg/log"

	cosv1 "marklu.com/example/api/v1"
)

// BucketReconciler reconciles a Bucket object
type BucketReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

const (
	bucketFinalizerName = "bucket.cos.marklu.com/finalizer"
)

//+kubebuilder:rbac:groups=cos.marklu.com,resources=buckets,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=cos.marklu.com,resources=buckets/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=cos.marklu.com,resources=buckets/finalizers,verbs=update

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
// TODO(user): Modify the Reconcile function to compare the state specified by
// the Bucket object against the actual cluster state, and then
// perform operations to make the cluster state reflect the state specified by
// the user.
//
// For more details, check Reconcile and its Result here:
// - https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.10.0/pkg/reconcile
func (r *BucketReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	bucket := &cosv1.Bucket{}
	if err := r.Get(ctx, req.NamespacedName, bucket); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	// examine DeletionTimestamp to determine if object is under deletion
	if bucket.ObjectMeta.DeletionTimestamp.IsZero() {
		// The object is not being deleted, so if it does not have our finalizer,
		// then lets add the finalizer and update the object. This is equivalent
		// registering our finalizer.
		if !controllerutil.ContainsFinalizer(bucket, bucketFinalizerName) {
			controllerutil.AddFinalizer(bucket, bucketFinalizerName)
			if err := r.Update(ctx, bucket); err != nil {
				return ctrl.Result{}, err
			}
		} else {
			if err := r.updateExternalResources(bucket); err != nil {
				logger.Error(err, "unable to create Bucket")
				return ctrl.Result{}, err
			}
			logger.Info("create Bucket succeed")
		}
	} else {
		// The object is being deleted
		if controllerutil.ContainsFinalizer(bucket, bucketFinalizerName) {
			// our finalizer is present, so lets handle any external dependency
			if err := r.deleteExternalResources(bucket); err != nil {
				// if fail to delete the external dependency here, return with error
				// so that it can be retried
				logger.Error(err, "unable to delete Bucket")
				return ctrl.Result{}, err
			}

			// remove our finalizer from the list and update it.
			controllerutil.RemoveFinalizer(bucket, bucketFinalizerName)
			if err := r.Update(ctx, bucket); err != nil {
				return ctrl.Result{}, err
			}
			logger.Info("delete Bucket succeed")
		}

		// Stop reconciliation as the item is being deleted
		return ctrl.Result{}, nil
	}

	// bucket reconcile logic
	return ctrl.Result{}, nil
}

func (r *BucketReconciler) updateExternalResources(bucket *cosv1.Bucket) error {
	cosClient := NewCosStorage(bucket.Spec.Region, bucket.Spec.Name)
	return cosClient.Put(bucket.Spec.ACL)
}

func (r *BucketReconciler) deleteExternalResources(bucket *cosv1.Bucket) error {
	cosClient := NewCosStorage(bucket.Spec.Region, bucket.Spec.Name)
	return cosClient.Delete()
}

// SetupWithManager sets up the controller with the Manager.
func (r *BucketReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&cosv1.Bucket{}).
		Complete(r)
}
```
# Test It Out
> 1. Install the CRDs into the cluster (make install)
```
[marklu@MacBook ~]$ make install
/Users/huyuhan/Project/workspace-go/example/bin/controller-gen rbac:roleName=manager-role crd webhook paths="./..." output:crd:artifacts:config=config/crd/bases
/Users/huyuhan/Project/workspace-go/example/bin/kustomize build config/crd | kubectl apply -f -
customresourcedefinition.apiextensions.k8s.io/buckets.cos.marklu.com created
```
> 2. Run your controller (this will run in the foreground, so switch to a new terminal if you want to leave it running) (make run)
```
[marklu@MacBook ~]$ make run
/Users/huyuhan/Project/workspace-go/example/bin/controller-gen rbac:roleName=manager-role crd webhook paths="./..." output:crd:artifacts:config=config/crd/bases
/Users/huyuhan/Project/workspace-go/example/bin/controller-gen object:headerFile="hack/boilerplate.go.txt" paths="./..."
go fmt ./...
go vet ./...
go run ./main.go
2022-01-27T22:05:30.207+0800	INFO	controller-runtime.metrics	metrics server is starting to listen	{"addr": ":8080"}
2022-01-27T22:05:30.207+0800	INFO	setup	starting manager
2022-01-27T22:05:30.208+0800	INFO	starting metrics server	{"path": "/metrics"}
2022-01-27T22:05:30.208+0800	INFO	controller.bucket	Starting EventSource	{"reconciler group": "cos.marklu.com", "reconciler kind": "Bucket", "source": "kind source: /, Kind="}
2022-01-27T22:05:30.208+0800	INFO	controller.bucket	Starting Controller	{"reconciler group": "cos.marklu.com", "reconciler kind": "Bucket"}
2022-01-27T22:05:30.309+0800	INFO	controller.bucket	Starting workers	{"reconciler group": "cos.marklu.com", "reconciler kind": "Bucket", "worker count": 1}
```
> 3. Create Custom Resources (create bucket.cos.marklu.com/bucket-sample) (cos_v1_bucket.yaml)
```
apiVersion: cos.marklu.com/v1
kind: Bucket
metadata:
  name: bucket-sample
  namespace: marklu
spec:
  # TODO(user): Add fields here
  name: example-1251762279
  region: ap-shanghai
  acl: private
```
kubectl apply -f cos_v1_bucket.yaml
```
[marklu@MacBook ~]$ kubectl apply -f cos_v1_bucket.yaml
bucket.cos.marklu.com/bucket-sample created
[marklu@MacBook ~]$ kubectl get bucket.cos.marklu.com  -n marklu
NAME            AGE
bucket-sample   17s
```
Tencent cloud console view found that the bucket was created normally.
> 4. Delete Instances of Custom Resources (delete bucket.cos.marklu.com/bucket-sample)
```
[marklu@MacBook ~]$ kubectl delete -f cos_v1_bucket.yaml
bucket.cos.marklu.com "bucket-sample" deleted
```
# Run It On the Cluster
> Deploy the controller to the cluster with image specified by IMG
```
make docker-build docker-push IMG=<some-registry>/<project-name>:tag
make deploy IMG=<some-registry>/<project-name>:tag
```
# Reference documentation
- https://github.com/kubernetes-sigs/kubebuilder
- https://book.kubebuilder.io/introduction.html
- https://kubernetes.io/docs/concepts/extend-kubernetes/operator/