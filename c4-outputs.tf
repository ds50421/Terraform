output "arn" {
  description = "ARN of the S3 Bucket"
  value       = aws_s3_bucket.s3_bucket.arn
}

output "name" {
  description = "Name (id) of the bucket"
  value       = aws_s3_bucket.s3_bucket.id
}

output "domain" {
  description = "Domain Name of the bucket"
  value       = aws_s3_bucket.s3_bucket.website_domain
}

output "endpoint" {
  description = "Endpoint Information of the bucket"
  value       = aws_s3_bucket.s3_bucket.website_endpoint
}

#codedeploy
output "arncodedeploy" {
  description = "ARN of the codedeploy"
  value       = aws_codedeploy_app.example.arn
}

output "namecodedeploy" {
  description = "Name (id) of the bucket"
  value       = aws_codedeploy_app.example.name
}

output "launch_template_id" {
  description = "Launch Template ID"
  value       = aws_launch_template.launch_temp_BAS.id
}

output "launch_template_latest_version" {
  description = "Launch Template Latest Version"
  value       = aws_launch_template.launch_temp_BAS.latest_version
}
# Autoscaling Outputs
output "autoscaling_group_id" {
  description = "Autoscaling Group ID"
  value       = aws_autoscaling_group.my_asg.id
}

output "autoscaling_group_name" {
  description = "Autoscaling Group Name"
  value       = aws_autoscaling_group.my_asg.name
}

output "autoscaling_group_arn" {
  description = "Autoscaling Group ARN"
  value       = aws_autoscaling_group.my_asg.arn
}

#codepipeline output

output "code_pipeline_id" {
  description = "Autoscaling Group Name"
  value       = aws_codepipeline.codepipeline.id
}

output "code_pipeline_arn" {
  description = "Autoscaling Group ARN"
  value       = aws_codepipeline.codepipeline.arn
}

output "code_deploygroup_arn" {
  description = "Autoscaling Group Name"
  value       = aws_codedeploy_deployment_group.main.arn
}

output "code_deploygroup_id" {
  description = "Autoscaling Group ARN"
  value       = aws_codedeploy_deployment_group.main.id
}

output "code_deploymentgroup_name" {
  description = "Autoscaling Group ARN"
  value       = aws_codedeploy_deployment_group.main.deployment_group_name
}


