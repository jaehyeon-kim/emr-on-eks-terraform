#!/usr/bin/env bash

# write test script
mkdir -p scripts/src
cat << EOF > scripts/src/threadsleep.py
import sys
from time import sleep
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName("threadsleep").getOrCreate()
def sleep_for_x_seconds(x):sleep(x*20)
sc=spark.sparkContext
sc.parallelize(range(1,6), 5).foreach(sleep_for_x_seconds)
spark.stop()
EOF

# write pod templates
mkdir -p scripts/config
cat << EOF > scripts/config/driver-template.yaml
apiVersion: v1
kind: Pod
spec:
  nodeSelector:
    type: 'karpenter'
    provisioner: 'spark-driver'
  tolerations:
    - key: 'spark-driver'
      operator: 'Exists'
      effect: 'NoSchedule'
  containers:
  - name: spark-kubernetes-driver
EOF

cat << EOF > scripts/config/executor-template.yaml
apiVersion: v1
kind: Pod
spec:
  nodeSelector:
    type: 'karpenter'
    provisioner: 'spark-executor'
  tolerations:
    - key: 'spark-executor'
      operator: 'Exists'
      effect: 'NoSchedule'
  containers:
  - name: spark-kubernetes-executor
EOF

# sync to S3
DEFAULT_BUCKET_NAME=$(terraform -chdir=./infra output --raw default_bucket_name)
aws s3 sync . s3://$DEFAULT_BUCKET_NAME --exclude "*" --include "scripts/*" 