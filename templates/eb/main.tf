terraform {
  backend "s3" {
    # NB: bucket e region vengono riscritti dalla pipeline (sed) prima di
    # 'terraform init'. Il backend S3 non supporta le variabili, quindi qui
    # restano valori "placeholder": la pipeline li rende dinamici.
    #
    # ATTENZIONE: la 'key' NON viene toccata dalla pipeline. Deve restare
    # identica a quella dello state gia' esistente di lifeviticase, altrimenti
    # Terraform cerca uno state vuoto e riprova a creare tutto da zero.
    bucket       = "PLACEHOLDER-STATE-BUCKET"
    key          = "beanstalk/lifeviticase.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# VARIABILI - alimentate dagli input del reusable workflow via TF_VAR_*
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "Regione AWS di deploy (deve combaciare con VPC/subnet/certificato)"
  type        = string
}

variable "application_name" {
  description = "Nome della Elastic Beanstalk Application"
  type        = string
}

variable "environment_name" {
  description = "Nome dell'ambiente Elastic Beanstalk"
  type        = string
}

variable "project_tag" {
  description = "Valore del tag PROJECT e prefisso nomi WAF"
  type        = string
}

variable "solution_stack_name" {
  description = "Solution stack EB (risolto dinamicamente dalla pipeline)"
  type        = string
}

variable "vpc_id" {
  description = "VPC in cui creare l'ambiente"
  type        = string
}

variable "subnets" {
  description = "Subnet (elenco separato da virgola) per istanze e load balancer"
  type        = string
}

variable "ssl_certificate_arn" {
  description = "ARN del certificato ACM (stessa regione dell'ALB) per il listener 443"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t4g.small"
}

variable "instance_architecture" {
  type    = string
  default = "arm64"
}

variable "min_size" {
  type    = string
  default = "1"
}

variable "max_size" {
  type    = string
  default = "1"
}

variable "health_check_path" {
  type    = string
  default = "/services/health/check"
}

variable "root_volume_type" {
  type    = string
  default = "gp3"
}

variable "root_volume_size" {
  type    = string
  default = "10"
}

variable "jvm_xms" {
  type    = string
  default = "512m"
}

variable "jvm_xmx" {
  type    = string
  default = "1538m"
}

variable "ec2_instance_profile_name" {
  description = "Nome dell'instance profile EB EC2 (condiviso a livello account, gestito dalla pipeline, NON da Terraform)."
  type        = string
  default     = "aws-elasticbeanstalk-ec2-role"
}

# Account corrente: usato per costruire l'ARN del service role senza passarlo.
data "aws_caller_identity" "current" {}

# 1. Beanstalk Application
resource "aws_elastic_beanstalk_application" "app" {
  name        = var.application_name
  description = "Elastic Beanstalk application for ${var.project_tag}"

  tags = {
    PROJECT = var.project_tag
  }
}

# 2. Ambiente Elastic Beanstalk
resource "aws_elastic_beanstalk_environment" "env" {
  name                = var.environment_name
  application         = aws_elastic_beanstalk_application.app.name
  solution_stack_name = var.solution_stack_name

  ### --- Networking ---
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = var.vpc_id
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = var.subnets
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "true"
  }

  ### --- Load Balancer ---
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }
  setting {
    namespace = "aws:elbv2:listener:443"
    name      = "ListenerEnabled"
    value     = "true"
  }
  setting {
    namespace = "aws:elbv2:listener:443"
    name      = "Protocol"
    value     = "HTTPS"
  }
  setting {
    namespace = "aws:elbv2:listener:443"
    name      = "SSLCertificateArns"
    value     = var.ssl_certificate_arn
  }
  setting {
    namespace = "aws:elbv2:listener:default"
    name      = "ListenerEnabled"
    value     = "false"
  }

  ### --- Environment Processes ---
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "Port"
    value     = "80"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "HealthCheckPath"
    value     = var.health_check_path
  }

  ### --- Health log streaming ---
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs:health"
    name      = "HealthStreamingEnabled"
    value     = "true"
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs:health"
    name      = "DeleteOnTerminate"
    value     = "true"
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs:health"
    name      = "RetentionInDays"
    value     = "7"
  }

  ### --- Managed Platform Updates ---
  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "ManagedActionsEnabled"
    value     = "true"
  }
  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "PreferredStartTime"
    value     = "Mon:08:50"
  }
  setting {
    namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
    name      = "UpdateLevel"
    value     = "patch"
  }
  setting {
    namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
    name      = "InstanceRefreshEnabled"
    value     = "true"
  }

  ### --- Rolling Updates & Deployments ---
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "DeploymentPolicy"
    value     = "RollingWithAdditionalBatch"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "BatchSizeType"
    value     = "Percentage"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "BatchSize"
    value     = "30"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "RollingUpdateType"
    value     = "Health"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "MaxBatchSize"
    value     = "1"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "MinInstancesInService"
    value     = "2"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "PauseTime"
    value     = "60"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "IgnoreHealthCheck"
    value     = "false"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "Timeout"
    value     = "600"
  }

  ### --- Launch configuration ---
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "RootVolumeType"
    value     = var.root_volume_type
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "RootVolumeSize"
    value     = var.root_volume_size
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "RootVolumeIOPS"
    value     = "3000"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "RootVolumeThroughput"
    value     = "125"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = var.instance_type
  }
  setting {
    namespace = "aws:ec2:instances"
    name      = "SupportedArchitectures"
    value     = var.instance_architecture
  }
  setting {
    namespace = "aws:ec2:instances"
    name      = "EnableSpot"
    value     = "true"
  }
  setting {
    namespace = "aws:ec2:instances"
    name      = "SpotFleetOnDemandBase"
    value     = "1"
  }
  setting {
    namespace = "aws:ec2:instances"
    name      = "SpotFleetOnDemandAboveBasePercentage"
    value     = "70"
  }
  setting {
    namespace = "aws:ec2:instances"
    name      = "SpotAllocationStrategy"
    value     = "capacity-optimized"
  }

  ### --- Scaling ---
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = var.min_size
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = var.max_size
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "Availability Zones"
    value     = "Any"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "Cooldown"
    value     = "360"
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "MeasureName"
    value     = "UnHealthyHostCount"
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "Unit"
    value     = "Count"
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "Statistic"
    value     = "Maximum"
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "Period"
    value     = "5"
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "BreachDuration"
    value     = "5"
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "UpperThreshold"
    value     = "1"
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "UpperBreachScaleIncrement"
    value     = "1"
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "LowerThreshold"
    value     = "0"
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "LowerBreachScaleIncrement"
    value     = "-1"
  }

  ### --- JVM / Container ---
  setting {
    namespace = "aws:elasticbeanstalk:environment:proxy"
    name      = "ProxyServer"
    value     = "apache"
  }
  setting {
    namespace = "aws:elasticbeanstalk:container:tomcat:jvmoptions"
    name      = "Xms"
    value     = var.jvm_xms
  }
  setting {
    namespace = "aws:elasticbeanstalk:container:tomcat:jvmoptions"
    name      = "Xmx"
    value     = var.jvm_xmx
  }
  setting {
    namespace = "aws:elasticbeanstalk:container:tomcat:jvmoptions"
    name      = "JVM Options"
    value     = "-XX:MetaspaceSize=64m -XX:MaxMetaspaceSize=352m -XX:NativeMemoryTracking=off -XX:SoftRefLRUPolicyMSPerMB=50 --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.io=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-opens java.base/java.util.concurrent=ALL-UNNAMED --add-opens java.rmi/sun.rmi.transport=ALL-UNNAMED"
  }

  ### --- Monitoring & Logging ---
  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }
  setting {
    name      = "ConfigDocument"
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    value     = "{\"Rules\": { \"Environment\": { \"Application\": { \"ApplicationRequests4xx\": { \"Enabled\": true } }, \"ELB\": { \"ELBRequests4xx\": {\"Enabled\": true } } } }, \"Version\": 1 }"
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "StreamLogs"
    value     = "true"
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "RetentionInDays"
    value     = "7"
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "DeleteOnTerminate"
    value     = "false"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "EnableXRay"
    value     = "true"
  }


  setting {
    namespace = "aws:elasticbeanstalk:hostmanager"
    name      = "LogPublicationControl"
    value     = "true"
  }

  ### --- Roles ---
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-elasticbeanstalk-service-role"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = var.ec2_instance_profile_name
  }

  ### --- Tags ---
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "project"
    value     = var.project_tag
  }

  tags = {
    PROJECT = var.project_tag
  }
}

# NB: il ruolo/instance profile EB EC2 (var.ec2_instance_profile_name) e'
# infrastruttura condivisa a livello di account: viene garantito esistente
# dalla pipeline (step "Ensure EB EC2 instance profile") e NON e' gestito qui,
# per evitare collisioni di state fra progetti diversi nello stesso account.

# Regex pattern set con i metodi consentiti
resource "aws_wafv2_regex_pattern_set" "valid_http_methods" {
  name        = "allowed-http-methods"
  description = "Permette solo i metodi HTTP standard"
  scope       = "REGIONAL"

  regular_expression {
    regex_string = "^GET$"
  }
  regular_expression {
    regex_string = "^POST$"
  }
  regular_expression {
    regex_string = "^PUT$"
  }
  regular_expression {
    regex_string = "^DELETE$"
  }
  regular_expression {
    regex_string = "^PATCH$"
  }
}

resource "aws_wafv2_regex_pattern_set" "blocked_http_methods" {
  name  = "http-methods-blocked"
  scope = "REGIONAL"

  regular_expression {
    regex_string = "^PROPFIND$"
  }
  regular_expression {
    regex_string = "^TRACE$"
  }
  regular_expression {
    regex_string = "^TRACK$"
  }
  regular_expression {
    regex_string = "^CONNECT$"
  }
  regular_expression {
    regex_string = "^OPTIONS$"
  }
}

resource "aws_wafv2_regex_pattern_set" "path_services" {
  name        = "allowed-path-prefix-services"
  description = "Permette solo URL che iniziano con /services/"
  scope       = "REGIONAL"

  regular_expression {
    regex_string = "^/services/[A-Za-z0-9\\-._~/]*$"
  }
}

# Load Balancer EB come data source
data "aws_lb" "eb_alb" {
  arn = tolist(aws_elastic_beanstalk_environment.env.load_balancers)[0]
}

# WebACL
resource "aws_wafv2_web_acl" "waf" {
  name        = "eb-waf-${var.project_tag}"
  description = "WAF per Elastic Beanstalk ${var.project_tag}"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "eb-waf-${var.project_tag}"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AllowValidHttpMethods"
    priority = 6

    action {
      allow {}
    }

    statement {
      regex_pattern_set_reference_statement {
        arn = aws_wafv2_regex_pattern_set.valid_http_methods.arn

        field_to_match {
          method {}
        }

        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AllowValidHttpMethods"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-CommonRules"
    priority = 1
    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSCommonRules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "BlockInvalidHttpMethods"
    priority = 2

    action {
      block {}
    }

    statement {
      regex_pattern_set_reference_statement {
        arn = aws_wafv2_regex_pattern_set.blocked_http_methods.arn

        field_to_match {
          method {}
        }

        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockInvalidHttpMethods"
      sampled_requests_enabled   = true
    }
  }

  tags = {
    PROJECT = var.project_tag
  }
}

# Associazione WAF <-> ALB
resource "aws_wafv2_web_acl_association" "waf" {
  resource_arn = data.aws_lb.eb_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.waf.arn
}
