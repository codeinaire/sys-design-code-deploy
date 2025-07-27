graph TD
subgraph "User Interaction"
User(fa:fa-user User)
APIGW(API Gateway)
end

         subgraph "Build & Deploy Pipeline"
             direction LR

        subgraph "1. Build Stage"
            BuildQueue(SQS: build-jobs-queue)
            BuildLambda(λ: build-worker)
        end

        subgraph "2. Replication Stage"
            GlobalS3(S3: global-builds)
            DeployQueue(SQS: deployment-jobs-queue)
            ReplicationLambda(λ: replication-worker)
            ReplicationDB(DB: replication-status)
        end

        subgraph "3. Regional Deployment Stage"
            RegionAS3(S3: region-a-builds)
            RegionBS3(S3: region-b-builds)
            SyncLambda(λ: regional-sync-worker)
            HostDB(DB: host-deployment-logs)
        end

        %% Connections
            APIGW -- "sends job to" --> BuildQueue
            BuildQueue -- "triggers" --> BuildLambda
            BuildLambda -- "writes artifact to" --> GlobalS3
            GlobalS3 -- "triggers on create" --> DeployQueue
            DeployQueue -- "triggers" --> ReplicationLambda
            ReplicationLambda -- "updates" --> ReplicationDB
            ReplicationLambda -- "copies to" --> RegionAS3
            ReplicationLambda -- "copies to" --> RegionBS3
            RegionAS3 -- "triggers" --> SyncLambda
            RegionBS3 -- "triggers" --> SyncLambda
            SyncLambda -- "writes 2000 host logs to" --> HostDB
        end

        User -- "POST /builds" --> APIGW
