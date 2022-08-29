export VIRTUAL_CLUSTER_ID=$(terraform -chdir=./infra output --raw emrcontainers_virtual_cluster_id)
export EMR_ROLE_ARN=$(terraform -chdir=./infra output --json emr_on_eks_role_arn | jq '.[0]' -r)
export CERTIFICATE_ARN=$(terraform -chdir=./infra output --raw aws_acm_certificate_emr_studio)
export AWS_REGION=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].[RegionName]' --output text)

aws emr-containers create-managed-endpoint \
--type JUPYTER_ENTERPRISE_GATEWAY \
--virtual-cluster-id $VIRTUAL_CLUSTER_ID \
--name virtual-emr-endpoint-demo \
--execution-role-arn $EMR_ROLE_ARN \
--release-label emr-6.7.0-latest \
--certificate-arn $CERTIFICATE_ARN \
--region $AWS_REGION \
--configuration-overrides '{
    "applicationConfiguration": [
      {
        "classification": "spark-defaults",
        "properties": {
          "spark.hadoop.hive.metastore.client.factory.class": "com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory",
          "spark.sql.catalogImplementation": "hive"
        }
      }
    ]
  }'
