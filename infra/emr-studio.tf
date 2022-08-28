resource "tls_private_key" "emr_studio" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "emr_studio" {
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.emr_studio.private_key_pem

  subject {
    common_name  = "*.emreksdemo.com"
    organization = "MyOrg"
  }

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "emr_studio" {
  private_key      = tls_private_key.emr_studio.private_key_pem
  certificate_body = tls_self_signed_cert.emr_studio.cert_pem
}

resource "aws_iam_policy" "s3_eks_policy" {
  name = "${local.name}-s3-eks-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
        ]
        Resource = [
          aws_s3_bucket.default_bucket.arn,
          "${aws_s3_bucket.default_bucket.arn}/*"
        ]
      }
    ]
  })
}
