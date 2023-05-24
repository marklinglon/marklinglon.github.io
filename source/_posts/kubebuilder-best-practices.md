---
title: Kubebuilder Best Practices
---
Kubebuilder is a framework for building Kubernetes APIs using custom resource definitions (CRDs).

Create a directory, and then run the init command inside of it to initialize a new project. Follows an example.

tips: Finalizers allow controllers to implement asynchronous pre-delete hooks. Let’s say you create an external resource (such as a storage bucket) for each object of your API type, and you want to delete the associated external resource on object’s deletion from Kubernetes, you can use a finalizer to do that.

/*
Copyright 2022 blazehu.

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

cosv1 "blazehu.com/example/api/v1"  
)

// BucketReconciler reconciles a Bucket object
type BucketReconciler struct {
client.Client
Scheme *runtime.Scheme
}

const (
bucketFinalizerName = "bucket.cos.blazehu.com/finalizer"
)

//+kubebuilder:rbac:groups=cos.blazehu.com,resources=buckets,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=cos.blazehu.com,resources=buckets/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=cos.blazehu.com,resources=buckets/finalizers,verbs=update

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