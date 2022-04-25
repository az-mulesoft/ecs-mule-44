#!/bin/bash

echo -e "\n+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo -e "+++++ Registration script begin: $(date) +++++ "
echo -e "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n"

#username=$ANYPOINT_USER
username=afzalmemon-mulesoft
#password=$ANYPOINT_PASS
password=Alisha2012Insha2009!
#orgName=$ANYPOINT_ORG
orgName="VA_DEMO"
#envName=$ANYPOINT_ENV
envName=Sandbox
#appName=$ANYPOINT_APPNAME
appName=qr-server
#anypointHost=$ANYPOINT_HOST
anypointHost=anypoint.mulesoft.com
ANYPOINT_CLIENTID=bac737b33f86417b88284c21b449428a
ANYPOINT_CLIENTSECRET=cFA843665f0c403382D334b4797e2E62
ANYPOINT_RUNTIME_MODE=NONE

if [[ ! $ANYPOINT_RUNTIME_MODE =~ ^(NONE|CLUSTER|SERVER_GROUP)$ ]]; then
    runtimeMode="SERVER_GROUP"
else
    runtimeMode=$ANYPOINT_RUNTIME_MODE
fi

serverName="$HOSTNAME"
groupOrClusterName=`echo "$appName" | awk '{print tolower($0)}'`

hybridAPI=https://$anypointHost/hybrid/api/v1
armuiAPI=https://$anypointHost/armui/api/v1
accAPI=https://$anypointHost/accounts

echo "env username = $username"
echo "env password = $password"
echo "env orgName = $orgName"
echo "env envName = $envName"
echo "env appName = $appName"
echo "env anypointHost = $anypointHost"
echo "env runtime mode = $runtimeMode"
echo "env serverName = $serverName"
echo "var group or cluster name = $groupOrClusterName"

echo "hybridAPI = $hybridAPI"
echo "armuiAPI = $armuiAPI"
echo "accAPI = $accAPI"

# Authenticate with user credentials (Note the APIs will NOT authorize for tokens received from the OAuth call. A user credentials is essential)

getAPIToken() {
  echo $(curl -sk $accAPI/login -X POST -d "username=$username&password=$password" | jq --raw-output .access_token)
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

# Get AMC server registration token
getRegistrationToken() {
  echo $(curl -s $hybridAPI/servers/registrationToken -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" | jq --raw-output .data)
}

# Get Server ID
getServerId() {
  curl -s $hybridAPI/servers/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken"
  serverData=$(curl -s $hybridAPI/servers/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
  jqParam=".data[] | select(.name==\"$serverName\").id"
  echo $(echo $serverData | jq --raw-output "$jqParam")
}

# Get Server IP
getServerIp() {
  echo $(cat /proc/sys/kernel/hostname)
#  echo $(hostname -i)
}

# Create app-specific wrapper-custom properties file
generateCustomWrapperPropsFile() {
  touch $MULE_HOME/conf/wrapper-custom.conf
  echo "#encoding=UTF-8" >> $MULE_HOME/conf/wrapper-custom.conf
  echo -e "-Danypoint.platform.client_id=$ANYPOINT_CLIENTID\n" >> $MULE_HOME/conf/wrapper-custom.conf
  echo -e "-Danypoint.platform.client_secret=$ANYPOINT_CLIENTSECRET\n" >> $MULE_HOME/conf/wrapper-custom.conf
  echo "$MULE_VARS" >> $MULE_HOME/conf/wrapper-custom.conf
}

# $1 = cluster or serverGroup
# $2 = cluster or group name
# $3 = cluster or group ID
addServerToClusterOrGroup() {
     # epoch miliseconds
     epochmseconds=$(($(date +%s%N)/1000000))
     clusterOrGroupId=$3

     # check if server already added, not expected
     server=$(curl -s $armuiAPI/servers?_"$epochmseconds" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
     jqparam=".data[] | select(.type==\"$1\" and .name==\"$2\").details"
     member=$(echo $server | jq --raw-output "$jqparam" | grep name | grep $serverName)
     if [[ "$member" != "" ]]; then
        echo "$(date +%Y-%m-%dT%T) - Server $serverName ($serverId) - has already been added to Cluster or Server Group: $2"
        return
     fi

     # Add the server to the requested cluster or server group
     if [[ "$1" == "CLUSTER" ]]; then    # add server to cluster
        uri="clusters/$clusterOrGroupId/servers"
        data="{\"serverId\":$serverId,\"serverIp\":\"$serverIp\"}"
     elif [[ "$1" == "SERVER_GROUP" ]]; then
        uri="serverGroups/$clusterOrGroupId/servers/$serverId"
        data="{\"serveGroupId\":$clusterOrGroupId,\"serverId\":$serverId}"
     fi
     curl -sf -X "POST" $hybridAPI/$uri?_="$epochmseconds" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" -H "Content-Type: application/json" -d "$data"
     if [[ $? != 0 ]]; then
        echo "$(date +%Y-%m-%dT%T) Adding the server to $2 ***** FAILED *****"
        return
     fi
     echo "$(date +%Y-%m-%dT%T) Server $serverName was added to $2"
}

checkClusterGroup() {
     server=$(curl -s $hybridAPI/$1 -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
     jqparam=".data[] | select(.name==\"$2\").id"
     clusterId=$(echo $server | jq "$jqparam")
     echo $clusterId
}

createClusterOrGroupAddServer() {
   # epoch miliseconds
   epochmseconds=$(($(date +%s%N)/1000000))

   if [[ "$1" == "CLUSTER" ]]; then
      data="{\"name\":\"$2\",\"multicastEnabled\":false,\"servers\":[{\"serverId\":$serverId,\"serverIp\":\"$serverIp\"}]}"
      cgType="clusters"
   elif [[ "$1" == "SERVER_GROUP" ]]; then
      data="{\"name\":\"$2\",\"serverIds\":[$serverId]}"
      cgType="serverGroups"
   else
      return
   fi

   url="$hybridAPI/$cgType?_=$epochmseconds"
   clusterGroupFound=$(checkClusterGroup $cgType $2)

   if [[ "$clusterGroupFound" != "" ]]; then     # Exisitng cluster or group
      echo "$(date +%Y-%m-%dT%T) - Cluster or Group: $1 exists"
      addServerToClusterOrGroup $1 $2 $clusterGroupFound
   else                                       # Create cluster or server, add server with cluster creation
      clusterGroupFound=""
      while true
      do
         curl -sf -X "POST" $url -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" -H 'Content-Type: application/json' -d "$data"
         if [[ $? == 0 ]]; then
            echo "$(date +%Y-%m-%dT%T) - $2 cluster or server group creation succeeded"
            return
         else
            clusterGroupFound=$(checkClusterGroup $cgType $2)
            [[ "$clusterGroupFound" != "" ]] && break
            sleep 5
         fi
      done
      addServerToClusterOrGroup $1 $2 $clusterGroupFound
   fi
}

#Function to enable API analytics for the servers
enableAPIAnalytics(){
  # Get server ID, serverGroup ID or cluster ID and assign to targetId

  if [[ "$1" == "NONE" ]]; then                                         # individual server
     curl -s $hybridAPI/servers/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" | jq .
     serverData=$(curl -s $hybridAPI/servers/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
     echo "serverData:" $serverData
     echo "ServerIP:" $serverIp
     jqParam=".data[] | select(.name==\"$serverName\").id"
     targetId=$(echo $serverData | jq --raw-output "$jqParam")
  else                                                                  # Cluster or server group
     [[ "$1" == "CLUSTER" ]] && cgType="clusters" || cgType="serverGroups"
     clusterGroupFound=$(checkClusterGroup $cgType $2)                  # check cluster/server group exists
     if [[ $clusterGroupFound == 0 ]]; then
        echo "$(date +%Y-%m-%dT%T) - Cluster or Group: $1 NOT found"
        return
     fi
     # Find the cluster/serverGroup Id
     server=$(curl -s $hybridAPI/$cgType -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
     jqparam=".data[] | select(.name==\"$2\").id"
     targetId=$(echo $server | jq "$jqparam")
  fi

  ####### Enable Analytics
  componentId=$(curl -s $hybridAPI/targets/$targetId/components/  -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" | jq ".data[] | .component | select(.name==\"mule.agent.gw.http.service\").id")
  epochmseconds=$(($(date +%s%N)/1000000))
  curl -s -X PATCH $hybridAPI/targets/$targetId/components/$componentId?_="$epochmseconds" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" -H "Content-Type: application/json" -d '{"enabled":"true"}'

  ###### Enable ELK
  componentId=$(curl -s $hybridAPI/targets/$targetId/components/  -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" | jq ".data[] | .component | select(.name==\"mule.agent.gw.http.handler.log\").id")
  epochmseconds=$(($(date +%s%N)/1000000))
  curl -s -X PATCH $hybridAPI/targets/$targetId/components/$componentId?_="$epochmseconds" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" -H "Content-Type: application/json" -d '{"enabled":true,"configuration":{"fileName":"$MULE_HOME/logs/api-analytics.log","daysTrigger":1,"mbTrigger":100,"filePattern":"$MULE_HOME/logs/api-analytics-%d{yyyy-dd-MM}-%i.log","immediateFlush":true,"bufferSize":262144,"dateFormatPattern":"yyyy-MM-dd'\''T'\''HH:mm:ssSZ"}}'

  #forward logs to stdout via tail
  touch $MULE_HOME/logs/api-analytics.log
  tail -F $MULE_HOME/logs/api-analytics.log >> /proc/1/fd/1 &
}

# ###############################
# BEGIN STARTUP SEQUENCE
# ###############################

accessToken=$(getAPIToken)
orgId=$(getOrgId)
envId=$(getEnvId)
amcToken=$(getRegistrationToken)
serverIp=$(getServerIp)

echo "Access toke" $accessToken
echo "orgId:" $orgId
echo "evnID:" $evnId
echo "amcToken:" $amcToken
echo "serverID:" $serverId
echo "serverName:" $serverName
echo "serverStatus:" $serverStatus

echo -A https://$anypointHost/hybrid/api/v1 -W "wss://$anypointHost:8889/mule" -D https://$anypointHost/apigateway/ccs -F https://$anypointHost/apiplatform -C https://$anypointHost/accounts -H "$amcToken" "$serverName"

#$MULE_HOME/bin/amc_setup -A https://$anypointHost/hybrid/api/v1 -W "wss://$anypointHost:8889/mule" -D https://$anypointHost/apigateway/ccs -F https://$anypointHost/apiplatform -C https://$anypointHost/accounts -H "$amcToken" "$serverName"
$MULE_HOME/bin/amc_setup -H "$amcToken" "$serverName"

generateCustomWrapperPropsFile

# Register license
$MULE_HOME/bin/mule -installLicense $MULE_HOME/conf/license.lic

# update wrapper.conf for analytics
sed -i '/anypoint.platform.analytics_enabled/s/false/true/' $MULE_HOME/conf/wrapper.conf
serverData=$(curl -s $hybridAPI/servers/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
echo $serverData

# Start mule runtime
nohup $MULE_HOME/bin/mule console & pid=$(/bin/ps -fu root| grep "wrapper-linux-x86-64" | awk '{print $2}')

jqParam=".data[] | select(.name==\"$serverName\")"
while true
do
  serverData=$(curl -s $hybridAPI/servers/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
  serverId=$(echo $serverData | jq --raw-output "$jqParam.id")
  serverStatus=$(echo $serverData | jq --raw-output "$jqParam.status")
  sleep 5
  [[ "$serverId" != "" && $serverStatus == "RUNNING" ]] && break || continue
  echo "Waiting for server to start..."
done

# Add server to group or cluster if mode is not NONE
if [ "$runtimeMode" != "NONE" ]; then
    createClusterOrGroupAddServer $runtimeMode $groupOrClusterName
fi

# Enable analytics
#enableAPIAnalytics $runtimeMode $groupOrClusterName

echo -e "\n\n+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo -e "+++++ Registration script end: $(date) +++++ "
echo -e "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n"
