# Create S3 Bucket Resource
resource "aws_s3_bucket" "s3_bucket" {
  bucket = var.bucket_name
  acl    = "private"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Sid": "PublicReadGetObject",
          "Effect": "Allow",
          "Principal": "*",
          "Action": [
              "s3:GetObject"
          ],
          "Resource": [
              "arn:aws:s3:::${var.bucket_name}/*"
          ]
      }
  ]
}  
EOF
  website {
    index_document = "index.html"
    error_document = "error.html"
  }
  tags          = var.tags
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.s3_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

#codepipeline artifacts stotage bucket
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "codepipeline-ds50421bas"
}

resource "aws_s3_bucket_acl" "codepipeline_bucket_acl" {
  bucket = aws_s3_bucket.codepipeline_bucket.id
  acl    = "private"
}


#create launch template

resource "aws_launch_template" "launch_temp_BAS" {
  name          = "launch_temp_BAS"
  description   = "Launch template for BAS"
  image_id      = data.aws_ami.amzlinux2.id
  instance_type = var.instance_type

  vpc_security_group_ids = [module.private_sg.security_group_id]
  key_name               = var.instance_keypair
  user_data              = filebase64("${path.module}/app1-install.sh")
  ebs_optimized          = true
  #default_version = 1
  update_default_version = true
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 10
      #volume_size = 20 # LT Update Testing - Version 2 of LT      
      delete_on_termination = true
      volume_type           = "gp2" # default is gp2
    }
  }
  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "AS-BAS"
    }
  }
}

# Autoscaling Group Resource
resource "aws_autoscaling_group" "my_asg" {
  name_prefix         = "ASG-BAS"
  desired_capacity    = 2
  max_size            = 10
  min_size            = 2
  vpc_zone_identifier = module.vpc.private_subnets
  #target_group_arns = module.alb.target_group_arns
  health_check_type = "EC2"
  #health_check_grace_period = 300 # default is 300 seconds  
  # Launch Template
  launch_template {
    id      = aws_launch_template.launch_temp_BAS.id
    version = aws_launch_template.launch_temp_BAS.latest_version
  }
  # Instance Refresh
  instance_refresh {
    strategy = "Rolling"
    preferences {
      #instance_warmup = 300 # Default behavior is to use the Auto Scaling Group's health check grace period.
      min_healthy_percentage = 50
    }
    triggers = [/*"launch_template",*/ "desired_capacity"] # You can add any argument from ASG here, if those has changes, ASG Instance Refresh will trigger
  }
  tag {
    key                 = "BAS"
    value               = "prod"
    propagate_at_launch = true
  }
}


# create a CodeDeploy application
resource "aws_codedeploy_app" "example" {
  compute_platform = "Server"
  name             = "BAS"
}

# create a deployment group
resource "aws_codedeploy_deployment_group" "main" {
  app_name              = aws_codedeploy_app.example.name
  deployment_group_name = "Sample_DepGroup"
  service_role_arn      = aws_iam_role.codedeploy_service.arn

  deployment_config_name = "CodeDeployDefault.OneAtATime" # AWS defined deployment config

   ec2_tag_filter {
    key   = "BAS"
    type  = "KEY_AND_VALUE"
    value = "prod"
  }

  # trigger a rollback on deployment failure event
  auto_rollback_configuration {
    enabled = true
    events = [
      "DEPLOYMENT_FAILURE",
    ]
  }
}

resource "aws_codedeploy_deployment_config" "demo_config" {
  deployment_config_name = "CodeDeployDefault2.EC2AllAtOnce"
  
  #traffic_routing_config {
  #  type = "AllAtOnce"
  #}
  # Terraform: Should be "null" for EC2/Server

  minimum_healthy_hosts {
    type  = "HOST_COUNT"
    value = 0
  }
}

#codepipeline

resource "aws_codepipeline" "codepipeline" {
  name     = "bas-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn
    artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = [
        "SourceArtifact",
      ]

      configuration = {
        S3Bucket   = aws_s3_bucket.s3_bucket.id
        S3ObjectKey = "deepak.zip"
        PollForSourceChanges       = "true"
      }
    }
  }

  stage {
    name = "approval-stage" # TODO: SNS

    action {
      name      = "TerraformPlanApproval"
      category  = "Approval"
      owner     = "AWS"
      provider  = "Manual"
      version   = "1"
      run_order = 1

      configuration = {
        CustomData = "Do you approve the plan?"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      run_order       =  1
      input_artifacts = [
        "SourceArtifact",
      ]
      output_artifacts = []
      configuration = {
        ApplicationName     = aws_codedeploy_app.example.name
        DeploymentGroupName   = aws_codedeploy_deployment_group.main.deployment_group_name
      }
    }
  }
}

#rule to trigger codepipeline via cloudwatch

resource "aws_cloudwatch_event_rule" "s3upload" {
  name        = "s3upload"
  description = "checks if s3 bucket is updated with zip file"
  event_pattern = <<EOF
{
	"source": [
		"aws.s3"
	],
	"detail-type": [
		"Object Created", "Object Restore Completed"
	],
	"detail": {
		"eventSource": [
			"s3.amazonaws.com"
		],
		"eventName": ["PutObject", "CopyObject", "CreateMultipartUpload", "PutObjectAcl", "HeadObject", "UploadPart", "UploadPartCopy", "PutObjectLockRetention", "PutObjectLockLegalHold"],
		"requestParameters": {
			"bucketName": [
				"aws_s3_bucket.s3_bucket.id"
			]
		}
	}
}
EOF
  
}

resource "aws_cloudwatch_event_target" "code-pipeline" {
  rule      = aws_cloudwatch_event_rule.s3upload.name
  #target_id = "triggercodepipeline"
  role_arn       = aws_iam_role.codepipeline_role.arn
  arn = aws_codepipeline.codepipeline.arn
}

