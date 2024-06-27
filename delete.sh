#!/bin/bash
delete_subscription(){
  currentCSV=$(oc get subscription $namespace -n $namespace -o yaml | grep currentCSV | sed 's/  currentCSV: //')
  echo $currentCSV
  oc delete subscription subscription $namespace -n $namespace
  oc delete clusterserviceversion $currentCSV -n $namespace
  oc delete namespace $namespace
}

set -x
PATH=${PWD}/bin/:$PATH

argocd login --core
oc project openshift-gitops
argocd app delete argocd-app-of-app -y
#TODO add application deletion
# delete resources
oc delete -f gitops/appofapp-char.yaml

#pipelines deletion
namespace=openshift-operators
subscription=openshift-pipelines-operator-rh
delete_subscription

#serverless deletion
namespace=openshift-serverless
subscription=serverless-operator
delete_subscription

#service-mesh deletion
oc delete smmr -n istio-system default
oc delete smcp -n istio-system basic
oc delete validatingwebhookconfiguration/openshift-operators.servicemesh-resources.maistra.io
oc delete mutatingwebhookconfiguration/openshift-operators.servicemesh-resources.maistra.io
oc delete -n openshift-operators daemonset/istio-node
oc delete clusterrole/istio-admin clusterrole/istio-cni clusterrolebinding/istio-cni
oc delete clusterrole istio-view istio-edit
oc delete clusterrole jaegers.jaegertracing.io-v1-admin jaegers.jaegertracing.io-v1-crdview jaegers.jaegertracing.io-v1-edit jaegers.jaegertracing.io-v1-view
oc get crds -o name | grep '.*\.istio\.io' | xargs -r -n 1 oc delete
oc get crds -o name | grep '.*\.maistra\.io' | xargs -r -n 1 oc delete
oc get crds -o name | grep '.*\.kiali\.io' | xargs -r -n 1 oc delete
oc delete crds jaegers.jaegertracing.io
oc delete project istio-system
namespace=openshift-operators
subscription=servicemeshoperator
delete_subscription

#rhods deletion
oc label configmap/delete-self-managed-odh api.openshift.com/addon-managed-odh-delete=true -n redhat-ods-operator
PROJECT_NAME=redhat-ods-applications
while oc get project $PROJECT_NAME &> /dev/null; do
  echo "The $PROJECT_NAME project still exists"
  sleep 1
done
echo "The $PROJECT_NAME project no longer exists"
oc delete namespace redhat-ods-operator
oc delete namespace redhat-ods-applications
oc delete namespace redhat-ods-monitoring
oc delete namespace redhat-ods-operator
oc delete namespace rhods-notebooks
currentCSV=$(oc get subscription rhods-operator -n redhat-ods-operator -o yaml | grep currentCSV | sed 's/  currentCSV: //')
echo $currentCSV
oc delete subscription subscription rhods-operator -n redhat-ods-operator
oc delete clusterserviceversion $currentCSV -n redhat-ods-operator


#delete  openshift-gitops operator resources
if [[ ${1:-1} = "1" ]]; then
  oc get argocd -n openshift-gitops openshift-gitops &>/dev/null
  if [[ $? = "0" ]]; then
    currentCSV=$(oc get subscription openshift-gitops-operator -n openshift-gitops-operator -o yaml | grep currentCSV | sed 's/  currentCSV: //')
    echo $currentCSV
    oc delete -f bootstrap/argocd-installation.yaml
    oc delete subscription openshift-gitops-operator -n openshift-gitops-operator
    oc delete clusterserviceversion $currentCSV  -n openshift-gitops-operator
  fi
fi
