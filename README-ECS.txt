Step 1: Build, Tag and Push Docker Container to AWS ECR

- docker build -t ecs-mule-44-v2 .
- docker tag ecs-mule-44-v2:latest <REG_URL>/ecs-mule-44-v2:latest
- aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin <REG_URL>
- docker push <<REG_URL>>/ecs-mule-44-v2:latest
- docker push <REG_URL>ecs-mule-44-v2:latest


Step 2: 
Create an ECS Cluster using the ECS UI tooling


Step 3: Task Definition (can also be done using UI tooling) 

{
  "ipcMode": null,
  "executionRoleArn": "arn:aws:iam::316491797044:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "dnsSearchDomains": null,
      "environmentFiles": null,
      "logConfiguration": {
        "logDriver": "awslogs",
        "secretOptions": null,
        "options": {
          "awslogs-group": "/ecs/mule-44-ircc-demo",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "entryPoint": null,
      "portMappings": [],
      "command": null,
      "linuxParameters": null,
      "cpu": 0,
      "environment": [
        {
          "name": "ANYPOINT_APPNAME",
          "value": "<>"
        },
        {
          "name": "ANYPOINT_CLIENTID",
          "value": "<>"
        },
        {
          "name": "ANYPOINT_CLIENTSECRET",
          "value": "<>"
        },
        {
          "name": "ANYPOINT_ENV",
          "value": "<>"
        },
        {
          "name": "ANYPOINT_HOST",
          "value": "anypoint.mulesoft.com"
        },
        {
          "name": "ANYPOINT_ORG",
          "value": "<ORG_NAME>"
        },
        {
          "name": "ANYPOINT_PASS",
          "value": "<>"
        },
        {
          "name": "ANYPOINT_RUNTIME_MODE",
          "value": "NONE"
        },
        {
          "name": "ANYPOINT_USER",
          "value": "<>"
        }
      ],
      "resourceRequirements": null,
      "ulimits": null,
      "dnsServers": null,
      "mountPoints": [],
      "workingDirectory": null,
      "secrets": null,
      "dockerSecurityOptions": null,
      "memory": null,
      "memoryReservation": 2048,
      "volumesFrom": [],
      "stopTimeout": null,
      "image": "public.ecr.aws/u0z0x0b6/ecs-mule-44-v2:latest",
      "startTimeout": null,
      "firelensConfiguration": null,
      "dependsOn": null,
      "disableNetworking": null,
      "interactive": null,
      "healthCheck": null,
      "essential": true,
      "links": null,
      "hostname": null,
      "extraHosts": null,
      "pseudoTerminal": null,
      "user": null,
      "readonlyRootFilesystem": null,
      "dockerLabels": null,
      "systemControls": null,
      "privileged": null,
      "name": "mule-44-register"
    }
  ],
  "placementConstraints": [],
  "memory": "2048",
  "taskRoleArn": "arn:aws:iam::316491797044:role/ecsTaskExecutionRole",
  "compatibilities": [
    "EC2",
    "FARGATE"
  ],
  "taskDefinitionArn": "arn:aws:ecs:us-east-1:316491797044:task-definition/mule-44-ircc-demo:1",
  "family": "mule-44-ircc-demo",
  "requiresAttributes": [
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.logging-driver.awslogs"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "ecs.capability.execution-role-awslogs"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.docker-remote-api.1.19"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.docker-remote-api.1.21"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.task-iam-role"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.docker-remote-api.1.18"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "ecs.capability.task-eni"
    }
  ],
  "pidMode": null,
  "requiresCompatibilities": [
    "FARGATE"
  ],
  "networkMode": "awsvpc",
  "runtimePlatform": {
    "operatingSystemFamily": "LINUX",
    "cpuArchitecture": null
  },
  "cpu": "256",
  "revision": 1,
  "status": "ACTIVE",
  "inferenceAccelerators": null,
  "proxyConfiguration": null,
  "volumes": []
}
