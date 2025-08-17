graph LR
%% Nodes
subgraph "Client & API"
U["User"]
APIGW["API Gateway (REST)"]
end

subgraph "Lambdas"
BuildFn["Lambda: build-worker"]
ReplicateFn["Lambda: replication-worker"]
InvokerFn["Lambda: step-function-invoker (manual)"]
end

subgraph "Buckets"
GlobalS3["S3: global-builds"]
RegionAS3["S3: region-a-builds"]
RegionBS3["S3: region-b-builds"]
end

subgraph "Workflow Orchestration"
SFN["Step Functions: file-copy-workflow"]
end

subgraph "Data Stores"
DDB["DynamoDB: FileCopyTracking"]
end

subgraph "Notifications"
SNS["SNS: file-copy-failures"]
end

%% API routes
U -->|"POST /builds"| APIGW
U -->|"POST /deploy"| APIGW

%% API -> Lambdas
APIGW -->|"Lambda proxy"| BuildFn
APIGW -->|"Lambda proxy"| ReplicateFn

%% Build path
BuildFn -->|"PutObject (artifact)"| GlobalS3

%% Event trigger to replication
GlobalS3 -. "S3:ObjectCreated .zip" .-> ReplicateFn

%% Replication lambda starts workflow
ReplicateFn -->|"StartExecution"| SFN

%% Manual invocation path
InvokerFn -->|"StartExecution (manual)"| SFN

%% Step Function actions
SFN -->|"CopyObject (Map)"| RegionAS3
SFN -->|"CopyObject (Map)"| RegionBS3
SFN -->|"PutItem/UpdateItem"| DDB
SFN -->|"Publish on failure"| SNS

%% Notes
classDef note fill:#fff,stroke:#bbb,stroke-dasharray: 3 3,color:#333
N1["Notes:<br/>- /builds uploads artifacts to global-builds<br/>- S3 event triggers replication-worker<br/>- State machine copies to regional buckets in parallel<br/>- Tracks results in DynamoDB; publishes failures via SNS"]:::note
