#!/bin/bash

PODIPS=`kubectl get pods -l app=workload -n default -o=jsonpath='{range .items[*]}{.status.podIP}'`
PODIPRESULT="true"
REGEXP="^100\.64\..*"

for ip in ${PODIPS[@]}
do
    if [[ $ip =~ $REGEXP ]]; then
        continue
    else
        PODIPRESULT="false"
        break
    fi
done

RESTARTS=`kubectl get pods -l app=workload -n default -o=jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}'`
RESTARTRESULT="true"

for restart in ${RESTARTS[@]}
do
    if [[ "$restart" -ne "0" ]]; then
        RESTARTRESULT="false"
        break
    fi
done

SYSTEMRESTARTS=`kubectl get pods -n kube-system -o=jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}'`
SYSTEMRESTARTRESULT="true"

for restart in ${SYSTEMRESTARTS[@]}
do
    if [[ "$restart" -ne "0" ]]; then
        SYSTEMRESTARTRESULT="false"
        break
    fi
done

NODECONFIG=`kubectl get ds aws-node -n kube-system -o json | jq '.spec.template.spec.containers[0].env'`
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

CHEAT="false"

POD_IMAGE=`kubectl get pods -l app=workload -n default -o=jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}'`

for image in ${POD_IMAGE[@]}
do
    if [[ $image != "rimaulana/wget-workload" ]]; then
        CHEAT="true"
        break
    fi
done

if [[ $CHEAT != "true" ]]; then
    POD_CMD=`kubectl get pods -l app=workload -n default -o=jsonpath='{range .items[*]}{.spec.containers[0].command}{"\n"}'`

    for cmd in ${POD_CMD[@]}
    do
        if [[ $cmd != "" ]]; then
            CHEAT="true"
            break
        fi
    done
fi

if [[ $CHEAT != "true" ]]; then
    POD_ARGS=`kubectl get pods -l app=workload -n default -o=jsonpath='{range .items[*]}{.spec.containers[0].args}{"\n"}'`

    for args in ${POD_ARGS[@]}
    do
        if [[ $args != "" ]]; then
            CHEAT="true"
            break
        fi
    done
fi

echo "{\"pod_ip\":\"$PODIPRESULT\",\"pod_restart\":\"$RESTARTRESULT\",\"system_pod_restart\":\"$SYSTEMRESTARTRESULT\",\"external_snat\":\"$EXTERNAL_SNAT\",\"config_label\":\"$CONFIG_LABEL\",\"cheat\":\"$CHEAT\"}" | jq .