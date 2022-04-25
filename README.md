# ecs-mule-44
Notes: 
1) Dockerfile requires mule ee to be placed in the same folder. Alternatively, it can be sourced from nexus or customer's private repo at the build time. 
2) Please update the task definition with following ENV Variables. 

$ANYPOINT_USER
$ANYPOINT_PASS
$ANYPOINT_ORG
$ANYPOINT_ENV
$ANYPOINT_APPNAME
$ANYPOINT_HOST
$ANYPOINT_CLIENTID
$ANYPOINT_CLIENTSECRET
$ANYPOINT_RUNTIME_MODE
