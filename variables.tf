variable "aws_region" {
  description = "The AWS region to create things in."
  default     = "us-west-2"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to cover in a given AWS region"
  default     = "3"
}

variable "asg_name" {
  default = "wp-app"
}

variable "ecs_instsg" {
  default = "ecs-instsg"
}

variable "key_name" {
  description = "Name of AWS ec2-key pair"
}

variable "instance_type" {
  default     = "t2.micro"
  description = "AWS instance type"
}

variable "scaleup_name" {
  description = "ASG scaleup group name"
  default     = "scaleup"
}

variable "scaledown_name" {
  description = "ASG scale down group name"
  default     = "scaledown"
}

variable "mem_high" {
  description = "High memory cloudwatch metric alarm"
  default     = "memoryreservation-high"
}

variable "mem_low" {
  description = "Low memory cloudwatch metric alarm"
  default     = "memoryreservation-low"
}

variable "metric_name" {
  description = "Cloud watch metric name space for scaling ASG"
  default     = "MemoryReservation"
}

variable "asg_min" {
  description = "Min numbers of servers in ASG"
  default     = "1"
}

variable "asg_max" {
  description = "Max numbers of servers in ASG"
  default     = "2"
}

variable "asg_desired" {
  description = "Desired numbers of servers in ASG"
  default     = "1"
}

variable "alb_healthy_threshold" {
  description = "ALB healthy threshold"
  default     = "2"
}

variable "alb_interval" {
  description = "ALB healthy threshold interval"
  default     = "15"
}

variable "alb_timeout" {
  description = "ALB timeout"
  default     = "10"
}

variable "unhealthy_threshold" {
  description = "ALB unhealthy threshold"
  default     = "5"
}

variable "ecs_role" {
  description = "ecs role"
  default     = "wp_ecs_role"
}

variable "ecs_policy" {
  description = "ecs_policy"
  default     = "wp_ecs_policy"
}

variable "ecs_profile" {
  description = "ecs_profile"
  default     = "wpinst_profile"
}

variable "instance_role" {
  description = "Iam role name"
  default     = "wp_instance_role"
}

variable "ecs_instance_role" {
  description = "ecs instance role"
  default     = "wp_instance_role"
}

variable "num_container" {
  description = "Desired Number of container"
  default     = "2"
}

variable "ecs_max_capacity" {
  description = "Max Number of container in cluster"
  default     = "2"
}

variable "ecs_min_capacity" {
  description = "Min Number of container in cluster"
  default     = "1"
}

variable "ecs_cluster_name" {
  default = "wp_app"
}

variable "container" {
  description = "Container name"
  default     = "wp_app"
}

variable "deployment_minimum_healthy_percent" {
  description = "deployment_minimum_healthy_percent"
  default     = "50"
}

variable "deployment_maximum_percent" {
  description = "deployment_maximum_percent"
  default     = "100"
}

variable "db_instance_type" {
  description = "Instance type"
  default     = "db.t2.micro"
}

variable "instance_name" {
  description = "Instance name"
  default     = "wpapp"
}

variable "db_name" {
  description = "Database name"
  default     = "wpapp"
}

variable "db_user" {
  description = "Database User"
  default     = "wpapp"
}

variable "db_pass" {}

variable "db_port" {
  description = "Database port"
  default     = "3306"
}

variable "container_port" {
  default = "80"
}

variable "group_app" {
  description = "Cloud watch log group for app"
  default     = "ecs-group/awp-app"
}

variable "group_ecs" {
  description = "Cloud watch log group for ecs"
  default     = "ecs-group/ecs-agent"
}
