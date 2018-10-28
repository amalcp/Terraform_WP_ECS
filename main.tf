#==================
# AWS Basic Config
#==================

provider "aws" {
  region = "${var.aws_region}"
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = "true"
  enable_dns_support   = "true"
}

resource "aws_subnet" "main" {
  count             = "${var.az_count}"
  cidr_block        = "${cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  vpc_id            = "${aws_vpc.main.id}"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route_table" "rtable" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }
}

resource "aws_route_table_association" "a" {
  count          = "${var.az_count}"
  subnet_id      = "${element(aws_subnet.main.*.id, count.index)}"
  route_table_id = "${aws_route_table.rtable.id}"
}

resource "aws_autoscaling_group" "app" {
  name                 = "${var.asg_name}"
  vpc_zone_identifier  = ["${aws_subnet.main.*.id}"]
  min_size             = "${var.asg_min}"
  max_size             = "${var.asg_max}"
  desired_capacity     = "${var.asg_desired}"
  launch_configuration = "${aws_launch_configuration.app.name}"
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.scaleup_name}"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 15
  autoscaling_group_name = "${aws_autoscaling_group.app.name}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.scaledown_name}"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 15
  autoscaling_group_name = "${aws_autoscaling_group.app.name}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "${var.mem_high}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "${var.metric_name}"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "80"

  dimensions {
    ClusterName = "${aws_ecs_cluster.main.name}"
  }

  alarm_actions = ["${aws_autoscaling_policy.scale_up.arn}"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_metric_alarm" "memory_low" {
  alarm_name          = "${var.mem_low}"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "${var.metric_name}"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "50"

  dimensions {
    ClusterName = "${aws_ecs_cluster.main.name}"
  }

  alarm_actions = ["${aws_autoscaling_policy.scale_down.arn}"]

  lifecycle {
    create_before_destroy = true
  }
}

data "template_file" "cloud_config" {
  template = "${file("${path.module}/cloud-config.tpl")}"

  vars {
    aws_region         = "${var.aws_region}"
    ecs_cluster_name   = "${aws_ecs_cluster.main.name}"
    ecs_log_level      = "info"
    ecs_agent_version  = "latest"
    ecs_log_group_name = "${aws_cloudwatch_log_group.ecs.name}"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-2018.03.e-amazon-ecs-optimized"]
  }
}

resource "aws_launch_configuration" "app" {
  security_groups = [
    "${aws_security_group.instance_sg.id}",
  ]

  key_name                    = "${var.key_name}"
  image_id                    = "${data.aws_ami.amazon_linux.id}"
  instance_type               = "${var.instance_type}"
  iam_instance_profile        = "${aws_iam_instance_profile.app.name}"
  user_data                   = "${data.template_file.cloud_config.rendered}"
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "lb_sg" {
  description = "controls access to the application ELB"

  vpc_id = "${aws_vpc.main.id}"
  name   = "tf-ecs-lbsg"

  ingress {
    protocol  = "tcp"
    from_port = 80
    to_port   = 80

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
}

resource "aws_security_group" "instance_sg" {
  description = "controls direct access to application instances"
  vpc_id      = "${aws_vpc.main.id}"
  name        = "${var.ecs_instsg}"

  ingress {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  ingress {
    protocol  = "tcp"
    from_port = 80
    to_port   = 80

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  ingress {
    protocol  = "tcp"
    from_port = 0
    to_port   = 65535

    security_groups = [
      "${aws_security_group.lb_sg.id}",
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds_sg" {
  description = "controls access to the mysql"

  vpc_id = "${aws_vpc.main.id}"
  name   = "rdssg"

  ingress {
    protocol  = "tcp"
    from_port = "${var.db_port}"
    to_port   = "${var.db_port}"

    security_groups = [
      "${aws_security_group.instance_sg.id}",
    ]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
}


#=============
# ECS Cluster
#=============

resource "aws_ecs_cluster" "main" {
  name = "${var.ecs_cluster_name}"
}

data "template_file" "task_definition" {
  template = "${file("${path.module}/task-definition.json")}"

  vars {
    image_url        = "wordpress"
    container_name   = "${var.container}"
    log_group_region = "${var.aws_region}"
    db_pass          = "${var.db_pass}"
    db_user          = "${var.db_user}"
    db_host          = "${aws_db_instance.db.address}"
    log_group_name   = "${aws_cloudwatch_log_group.app.name}"
  }
}

resource "aws_ecs_task_definition" "taskdef" {
  family                = "${aws_ecs_cluster.main.name}"
  container_definitions = "${data.template_file.task_definition.rendered}"
  network_mode = "awsvpc"
}

resource "aws_ecs_service" "ecsserv" {
  name                               = "${aws_ecs_cluster.main.name}"
  cluster                            = "${aws_ecs_cluster.main.id}"
  task_definition                    = "${aws_ecs_task_definition.taskdef.arn}"
  desired_count                      = "${var.num_container}"
  #iam_role                           = "${aws_iam_role.ecs_service.name}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"
  deployment_maximum_percent         = "${var.deployment_maximum_percent}"
  health_check_grace_period_seconds  = 120

  load_balancer {
    target_group_arn = "${aws_alb_target_group.trgtgrp.id}"
    container_name   = "${var.container}"
    container_port   = "${var.container_port}"
  }

  network_configuration {
    security_groups = ["${aws_security_group.instance_sg.id}"]
    subnets         = ["${aws_subnet.main.*.id}"]
  }

depends_on = ["aws_alb_listener.front_end"]
 
}

resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = "${var.ecs_max_capacity}"
  min_capacity       = "${var.ecs_min_capacity}"
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.ecsserv.name}"
  role_arn           = "${aws_iam_role.ecs_service.arn}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_scale_up" {
  name               = "scale-up"
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.ecsserv.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }

  depends_on = ["aws_appautoscaling_target.ecs_target"]
}

resource "aws_appautoscaling_policy" "ecs_policy" {
  name               = "scale-down"
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.ecsserv.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = -1
    }
  }

  depends_on = ["aws_appautoscaling_target.ecs_target"]
}

#================
# Setting up IAM
#================

resource "aws_iam_role" "ecs_service" {
  name = "${var.ecs_role}"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ecs_service" {
  name = "${var.ecs_policy}"
  role = "${aws_iam_role.ecs_service.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:RegisterTargets"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.ecs_profile}"
  role = "${aws_iam_role.app_instance.name}"
}

resource "aws_iam_role" "app_instance" {
  name = "${var.instance_role}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

data "template_file" "instance_profile" {
  template = "${file("${path.module}/instance-profile-policy.json")}"

  vars {
    app_log_group_arn = "${aws_cloudwatch_log_group.app.arn}"
    ecs_log_group_arn = "${aws_cloudwatch_log_group.ecs.arn}"
  }
}
resource "aws_iam_role_policy" "instance" {
  name   = "${var.ecs_instance_role}"
  role   = "${aws_iam_role.app_instance.name}"
  policy = "${data.template_file.instance_profile.rendered}"
}

#=================
# Creating ALB
#=================

resource "aws_alb_target_group" "trgtgrp" {
  name                 = "ecs"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = "${aws_vpc.main.id}"
  target_type          = "ip"
  deregistration_delay = 180

  health_check {
    healthy_threshold   = "${var.alb_healthy_threshold}"
    interval            = "${var.alb_interval}"
    path                = "/"
    timeout             = "${var.alb_timeout}"
    unhealthy_threshold = "${var.unhealthy_threshold}"
  }
}

resource "aws_alb" "main" {
  name            = "alb-ecs"
  subnets         = ["${aws_subnet.main.*.id}"]
  security_groups = ["${aws_security_group.lb_sg.id}"]
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = "${aws_alb.main.id}"
  port              = "80"
  protocol          = "HTTP"
  
  
  default_action {
    target_group_arn = "${aws_alb_target_group.trgtgrp.id}"
    type             = "forward"
  }
}

#===============
# RDS - MySql
#===============

data "aws_vpc" "default" {
  id = "${aws_vpc.main.id}"
}

data "aws_subnet_ids" "all" {
  vpc_id = "${data.aws_vpc.default.id}"
}

resource "aws_db_subnet_group" "mysql" {
  name       = "mysql"
  subnet_ids = ["${data.aws_subnet_ids.all.ids}"]
}

resource "aws_db_instance" "db" {
  instance_class          = "${var.db_instance_type}"
  identifier              = "${var.instance_name}"
  engine                  = "mysql"
  engine_version          = "5.7"
  username                = "${var.db_user}"
  password                = "${var.db_pass}"
  port                    = "${var.db_port}"
  storage_type            = "gp2"
  allocated_storage       = 20
  db_subnet_group_name    = "${aws_db_subnet_group.mysql.name}"
  vpc_security_group_ids  = ["${aws_security_group.rds_sg.id}"]
  skip_final_snapshot     = true
  publicly_accessible     = true
  backup_retention_period = 0
}

#================
#CloudWatch Logs
#================
resource "aws_cloudwatch_log_group" "ecs" {
  name = "${var.group_ecs}"
}

resource "aws_cloudwatch_log_group" "app" {
  name = "${var.group_app}"
}
