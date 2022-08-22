export VIRTUAL_CLUSTER_ID=$(terraform -chdir=./infra output --raw emrcontainers_virtual_cluster_id)
export EMR_ROLE_ARN=$(terraform -chdir=./infra output --json emr_on_eks_role_arn | jq '.[0]' -r)
export DEFAULT_BUCKET_NAME=$(terraform -chdir=./infra output --raw default_bucket_name)
export AWS_REGION=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].[RegionName]' --output text)

## without DRA
aws emr-containers start-job-run \
--virtual-cluster-id $VIRTUAL_CLUSTER_ID \
--name threadsleep-karpenter-wo-dra \
--execution-role-arn $EMR_ROLE_ARN \
--release-label emr-6.7.0-latest \
--region $AWS_REGION \
--job-driver '{
    "sparkSubmitJobDriver": {
        "entryPoint": "'${DEFAULT_BUCKET_NAME}'/scripts/src/threadsleep.py",
        "sparkSubmitParameters": "--conf spark.executor.instances=15 --conf spark.executor.memory=1G --conf spark.executor.cores=1 --conf spark.driver.cores=1"
        }
    }' \
--configuration-overrides '{
    "applicationConfiguration": [
      {
        "classification": "spark-defaults", 
        "properties": {
          "spark.dynamicAllocation.enabled":"false",
          "spark.kubernetes.executor.deleteOnTermination": "true",
          "spark.kubernetes.driver.podTemplateFile":"'${DEFAULT_BUCKET_NAME}'/scripts/config/driver-template.yaml", 
          "spark.kubernetes.executor.podTemplateFile":"'${DEFAULT_BUCKET_NAME}'/scripts/config/executor-template.yaml"
         }
      }
    ]
}'

## with DRA
aws emr-containers start-job-run \
--virtual-cluster-id $VIRTUAL_CLUSTER_ID \
--name threadsleep-karpenter-wo-dra \
--execution-role-arn $EMR_ROLE_ARN \
--release-label emr-6.7.0-latest \
--region $AWS_REGION \
--job-driver '{
    "sparkSubmitJobDriver": {
        "entryPoint": "'${DEFAULT_BUCKET_NAME}'/scripts/src/threadsleep.py",
        "sparkSubmitParameters": "--conf spark.executor.instances=1 --conf spark.executor.memory=1G --conf spark.executor.cores=1 --conf spark.driver.cores=1"
        }
    }' \
--configuration-overrides '{
    "applicationConfiguration": [
      {
        "classification": "spark-defaults", 
        "properties": {
          "spark.dynamicAllocation.enabled":"true",
          "spark.dynamicAllocation.shuffleTracking.enabled":"true",
          "spark.dynamicAllocation.minExecutors":"1",
          "spark.dynamicAllocation.maxExecutors":"10",
          "spark.dynamicAllocation.initialExecutors":"1",
          "spark.dynamicAllocation.schedulerBacklogTimeout": "1s",
          "spark.dynamicAllocation.executorIdleTimeout": "5s",
          "spark.kubernetes.driver.podTemplateFile":"'${DEFAULT_BUCKET_NAME}'/scripts/config/driver-template.yaml", 
          "spark.kubernetes.executor.podTemplateFile":"'${DEFAULT_BUCKET_NAME}'/scripts/config/executor-template.yaml"
         }
      }
    ]
}'