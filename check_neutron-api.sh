#!/bin/bash
set -e

. $(dirname $0)/apis_common.sh

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

usage ()
{
    echo "Usage: $0 [OPTIONS]"
    echo " -h                   Get help"
    echo " -H <Auth URL>        URL for obtaining an auth token. Default: http://localhost:5000/v2.0"
    echo " -E <Endpoint URL>    URL for neutron API. Default: http://localhost:9696/v2.0"
    echo " -T <admin project>   Admin project name to get an auth token"
    echo " -U <username>        Username to use to get an auth token"
    echo " -P <password>        Password to use ro get an auth token"
}

while getopts 'hH:U:T:P:E:' OPTION
do
    case $OPTION in
        h)
            usage
            exit 0
            ;;
        H)
            export OS_AUTH_URL=$OPTARG
            ;;
        E)
            export ENDPOINT_URL=$OPTARG
            ;;
        T)
            export OS_PROJECT_NAME=$OPTARG
            ;;
        U)
            export OS_USERNAME=$OPTARG
            ;;
        P)
            export OS_PASSWORD=$OPTARG
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

# User must provide at least non-empty parameters
[[ -z "${OS_PROJECT_NAME}" || -z "${OS_USERNAME}" || -z "${OS_PASSWORD}" ]] && (usage; exit 1)

# Set default values
OS_AUTH_URL=${OS_AUTH_URL:-"http://localhost:5000/v3"}
ENDPOINT_URL=${ENDPOINT_URL:-"http://localhost:9696/v2.0"}

if ! which curl >/dev/null 2>&1 || ! which python >/dev/null 2>&1
then
    echo "UNKNOWN: curl or python are not installed."
    exit $STATE_UNKNOWN
fi


get_catalog
get_token
get_project_id

TOKEN=$(echo $TOKEN | tr -d '\b\r')

# Check Neutron API
START=$(date +%s)
API_RESP=$(curl -s -H "X-Auth-Token: $TOKEN" -H "Content-type: application/json" ${ENDPOINT_URL}/networks || true)
END=$(date +%s)
if [ ! -z "${API_RESP}" ]; then
    NETWORKS=$(echo ${API_RESP} | python -c "import sys; import json; data = json.loads(sys.stdin.readline()); print data.get('networks',{})")
    if [ "${NETWORKS}" = "{}" ]; then
        echo "CRITICAL: Unable to retrieve a network for project ${OS_PROJECT} from Neutron API"
        exit $STATE_CRITICAL
    fi
else
    echo "CRITICAL: Unable to reach Neutron API"
    exit $STATE_CRITICAL
fi
