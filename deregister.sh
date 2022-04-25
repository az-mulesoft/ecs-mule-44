#!/bin/bash

echo -e "\n+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo -e "+++++ Deregistration script begin: $(date) +++++ "
echo -e "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n"

serverName="$HOSTNAME"
username="$ANYPOINT_USER"
password="$ANYPOINT_PASS"
anypoint_host="$ANYPOINT_HOST"
orgName="$ANYPOINT_ORG"
envName="$ANYPOINT_ENV"
appName="$ANYPOINT_APPNAME"
accAPI="https://$anypoint_host/accounts"
hybridAPI="https://$anypoint_host/hybrid/api/v1"
armuiAPI="https://$anypoint_host/armui/api/v1"

if [[ ! "$ANYPOINT_RUNTIME_MODE" =~ ^(NONE|CLUSTER|SERVER_GROUP)$ ]]; then
    runtime_mode="SERVER_GROUP"
else
    runtime_mode="$ANYPOINT_RUNTIME_MODE"
fi

groupOrClusterName=`echo "$appName" | awk '{print tolower($0)}'`

# Authenticate with user credentials (Note the APIs will NOT authorize for tokens received from the OAuth call. A user credentials is essential)
getAPIToken() {
  echo $(curl -s $accAPI/login -d "username=$username&password=$password" | jq --raw-output .access_token)
}

# Convert org name to ID
getOrgId() {
  jqParam=".user.contributorOfOrganizations[] | select(.name==\"$orgName\").id"
  echo $(curl -s $accAPI/api/me -H "Authorization:Bearer $accessToken" | jq --raw-output "$jqParam")
}

# Convert environment name to ID
getEnvId() {
  jqParam=".data[] | select(.name==\"$envName\").id"
  echo $(curl -s $accAPI/api/organizations/$orgId/environments -H "Authorization:Bearer $accessToken" | jq --raw-output "$jqParam")
}

# Get Server ID
getServerId() {
  jqParam=".data[] | select(.name==\"$serverName\")"
  serverData=$(curl -s $hybridAPI/servers/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
  echo $(echo $serverData | jq --raw-output "$jqParam.id")
}


##################################################################################################################
# Delete a cluster or server group
# Method: DELETE
deleteClusterGroup() {
   curl -sf -X "DELETE" $hybridAPI/$2/"$1"?_="$epochmseconds" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken"
   [[ ! $? == 0 ]] && echo "$(date +%Y-%m-%dT%T) - Error deleting $2 $1" || return 0
}

###################################################################################################################
# Delete server from cluster or server group
# Delete cluster or server group if no more servers left -- this may be a noise since pods get deleted/replaced
# at times causing cluster or server group to be recreated
#
# sample URL for deletion from a cluster: https://anypoint.xyz.gov/hybrid/api/v1/clusters/1625/servers/1568?_=1592409735152
# sample URL for deletion from a Server Group : https://anypoint.xyz.cbp.dhs.gov/hybrid/api/v1/serverGroups/1632/servers/1568?_=1592410294140
# sample URL for deletion from a Server Group : https://anypoint.xyz.dhs.gov/hybrid/api/v1/serverGroups/1632?_=1592410294140
# Request payload: None
# Method: DELETE

deleteServerFromClusterOrGroup() {
  epochmseconds=$(($(date +%s%N)/1000000))
  # Get cluster of server group
  servers=$(curl -sf $armuiAPI/servers?_"$epochmseconds" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
  echo $servers | jq -r .
  [[ ! $? ]] &&  echo "$(date +%Y-%m-%dT%T) - Error getting list of servers, clusters and-or server groups" && return

  # cluster/server group id
  jqparam=".data[] | select(.type==\"$1\" and .name==\"$2\").id"
  clusterGroupId=$(echo $servers | jq "$jqparam")

  # if server belongs to cluster or server group
  jqparam=".data[] | select(.type==\"$1\" and .name==\"$2\") | .details | .servers[] | select(.name==\"$serverName\").name"
  server=$(echo $servers | jq "$jqparam")        # if server=null, do nothing and return
  [[ -z server ]] && return

  # Remove server from cluster or server group
  [[ "$1" == "CLUSTER" ]] && type="clusters" || type="serverGroups"

  # delete server group or cluster if the last server in the cluster or group
  # a if not, just delete the server from the cluster or group

  jqParam=".data[] | select(.type==\"$1\" and .name==\"$2\").details.servers[].name"

  countServers=$(echo $servers | jq --raw-output "$jqParam" | wc -l)
  echo -e "\n=============================== Server Count: $countServers "

  serverRemaining=$(echo $servers | jq --raw-output "$jqParam")
  echo -e "=============================== Server Remaining: $serverRemaining "

  if [[ $((countServers)) -gt 1 ]]; then
     curl -sf -X "DELETE" $hybridAPI/$type/$clusterGroupId/servers/"$serverId"?_"$epochmseconds" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken"
     if [[ ! $? ]]; then
        echo -e "\n=============================== $(date +%Y-%m-%dT%T) - Error removing server from $1 $2."
     fi
  else
     if [[ $serverName == $serverRemaining ]]; then
        # remove cluster or server group
        deleteClusterGroup $clusterGroupId $type
        [[ ! $? ]] && echo "$(date +%Y-%m-%dT%T) - Error deleting cluster: $2" && return
     fi
 fi
}

# ###############################
# BEGIN SHUTDOWN SEQUENCE
# ###############################
accessToken=$(getAPIToken)
orgId=$(getOrgId)
envId=$(getEnvId)
serverId=$(getServerId)

echo -e "\n==================================================================================================="
echo -e "=============================== serverID = $serverId "
echo -e "=============================== orgID = $orgId "
echo -e "=============================== envID = $envId "
echo -e "=============================== access Token = $accessToken "
echo -e "===================================================================================================\n"


# Remove server from cluster or group
[[ "$runtime_mode" != "NONE" ]] && deleteServerFromClusterOrGroup "$runtime_mode" "$groupOrClusterName"

# Deregister mule from ARM
echo "=============================== Deregistering Server $serverName ($serverId) "
curl -s -X "DELETE" "$hybridAPI/servers/$serverId" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken"

echo -e "\n+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo -e "+++++ Deregistration script end: $(date) +++++ "
echo -e "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n"
