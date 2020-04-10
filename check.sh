#!/bin/bash

PODIPS=`kubectl --kubeconfig=/home/ec2-user/.kube/config get pods -l app=workload -n default -o=jsonpath='{range .items[*]}{.status.podIP}'`
PODIPRESULT="false"
REGEXP="^100\.64\..*"

for ip in ${PODIPS[@]}
do
    if [[ $ip =~ $REGEXP ]]; then
        PODIPRESULT="true"
    else
        PODIPRESULT="false"
        break
    fi
done

RESTARTS=`kubectl --kubeconfig=/home/ec2-user/.kube/config get pods -l app=workload -n default -o=jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}'`
RESTARTRESULT="false"

for restart in ${RESTARTS[@]}
do
    if [[ "$restart" -ne "0" ]]; then
        RESTARTRESULT="false"
        break
    else
        RESTARTRESULT="true"
    fi
done

SYSTEMRESTARTS=`kubectl --kubeconfig=/home/ec2-user/.kube/config get pods -n kube-system -o=jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}'`
SYSTEMRESTARTRESULT="false"

for restart in ${SYSTEMRESTARTS[@]}
do
    if [[ "$restart" -ne "0" ]]; then
        SYSTEMRESTARTRESULT="false"
        break
    else
        SYSTEMRESTARTRESULT="true"
    fi
done

NODECONFIG=`kubectl --kubeconfig=/home/ec2-user/.kube/config get ds aws-node -n kube-system -o json | jq '.spec.template.spec.containers[0].env'`
CONFIG_LABEL="false"
EXTERNAL_SNAT="false"

for row in $(echo "${NODECONFIG}" | jq -r '.[] | @base64'); do
    _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
    }

    NAME=$(_jq '.name')
    VALUE=$(_jq '.value')

    if [[ $NAME == "ENI_CONFIG_LABEL_DEF" ]]; then
        if [[ $VALUE == "failure-domain.beta.kubernetes.io/zone" ]]; then
            CONFIG_LABEL="true"
        fi
    fi

    if [[ $NAME == "AWS_VPC_K8S_CNI_EXTERNALSNAT" ]]; then
        if [[ $VALUE == "true" ]]; then
            EXTERNAL_SNAT="true"
        fi
    fi
done

CHEAT="true"

POD_IMAGE=`kubectl --kubeconfig=/home/ec2-user/.kube/config get pods -l app=workload -n default -o=jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}'`

for image in ${POD_IMAGE[@]}
do
    if [[ $image != "rimaulana/wget-workload" ]]; then
        CHEAT="true"
        break
    else
        CHEAT="false"
    fi
done

if [[ $CHEAT != "true" ]]; then
    POD_CMD=`kubectl --kubeconfig=/home/ec2-user/.kube/config get pods -l app=workload -n default -o=jsonpath='{range .items[*]}{.spec.containers[0].command}{"\n"}'`

    for cmd in ${POD_CMD[@]}
    do
        if [[ $cmd != "" ]]; then
            CHEAT="true"
            break
        fi
    done
fi

if [[ $CHEAT != "true" ]]; then
    POD_ARGS=`kubectl --kubeconfig=/home/ec2-user/.kube/config get pods -l app=workload -n default -o=jsonpath='{range .items[*]}{.spec.containers[0].args}{"\n"}'`

    for args in ${POD_ARGS[@]}
    do
        if [[ $args != "" ]]; then
            CHEAT="true"
            break
        fi
    done
fi

echo "{\"pod_ip\":\"$PODIPRESULT\",\"pod_restart\":\"$RESTARTRESULT\",\"system_pod_restart\":\"$SYSTEMRESTARTRESULT\",\"external_snat\":\"$EXTERNAL_SNAT\",\"config_label\":\"$CONFIG_LABEL\",\"cheat\":\"$CHEAT\"}" | jq .