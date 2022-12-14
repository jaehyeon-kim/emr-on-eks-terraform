# Manage EMR on EKS with Terraform

**UPDATE**

- tried to set up EMR studio but was not successful.
- use the [wo-studio](https://github.com/jaehyeon-kim/emr-on-eks-terraform/tree/wo-studio) branch.

[Manage EMR on EKS with Terraform](https://cevo.com.au/post/manage-emr-on-eks-with-terraform/)

- [Amazon EMR on EKS](https://aws.amazon.com/emr/features/eks/) is a deployment option for Amazon EMR that allows you to automate the provisioning and management of open-source big data frameworks on EKS. While [eksctl](https://eksctl.io/) is popular for working with [Amazon EKS](https://aws.amazon.com/eks/) clusters, it has limitations when it comes to building infrastructure that integrates multiple AWS services. Also it is not straightforward to update EKS cluster resources incrementally with it. On the other hand [Terraform](https://www.terraform.io/) can be an effective tool for managing infrastructure that includes not only EKS and EMR virtual clusters but also other AWS resources. Moreover Terraform has a wide range of [modules](https://www.terraform.io/language/modules) and it can even be simpler to build and manage infrastructure using those compared to the CLI tool. In this post, we’ll discuss how to provision and manage Spark jobs on EMR on EKS with Terraform. [Amazon EKS Blueprints for Terraform](https://aws-ia.github.io/terraform-aws-eks-blueprints/v4.7.0/) will be used for provisioning EKS, EMR virtual cluster and related resources. Also Spark job autoscaling will be managed by [Karpenter](https://karpenter.sh/) where two Spark jobs with and without [Dynamic Resource Allocation (DRA)](https://spark.apache.org/docs/latest/job-scheduling.html#dynamic-resource-allocation) will be compared.
