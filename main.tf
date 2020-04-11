module "naming" {
  source      = "git::https://github.com/MagnetarIT/terraform-naming-standard.git?ref=tags/0.1.0"
  namespace   = var.namespace
  environment = var.environment
  name        = var.name
  attributes  = var.attributes
  tags        = var.tags
}

resource "aws_security_group" "default" {
  description = "Controls access to the ALB (HTTP/HTTPS)"
  vpc_id      = var.vpc_id
  name        = module.naming.id
  tags        = module.naming.tags
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = "0"
  to_port           = "0"
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.default.id
}

resource "aws_security_group_rule" "http_ingress" {
  count             = var.http_enabled ? 1 : 0
  type              = "ingress"
  from_port         = var.http_port
  to_port           = var.http_port
  protocol          = "tcp"
  cidr_blocks       = var.http_ingress_cidr_blocks
  prefix_list_ids   = var.http_ingress_prefix_list_ids
  security_group_id = aws_security_group.default.id
}

resource "aws_security_group_rule" "https_ingress" {
  count             = var.https_enabled ? 1 : 0
  type              = "ingress"
  from_port         = var.https_port
  to_port           = var.https_port
  protocol          = "tcp"
  cidr_blocks       = var.https_ingress_cidr_blocks
  prefix_list_ids   = var.https_ingress_prefix_list_ids
  security_group_id = aws_security_group.default.id
}

data "aws_elb_service_account" "default" {
  count = var.access_logs_enabled ? 1 : 0
}

data "aws_iam_policy_document" "default" {
  count = var.access_logs_enabled ? 1 : 0

  statement {
    sid = ""

    principals {
      type        = "AWS"
      identifiers = [join("", data.aws_elb_service_account.default.*.arn)]
    }

    effect = "Allow"

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${module.naming.id}-alb-access-logs/*",
    ]
  }
}

module "access_logs" {
  source        = "git::https://github.com/MagnetarIT/terraform-aws-s3-logs.git?ref=tags/0.1.0"
  name          = var.name
  namespace     = var.namespace
  environment   = var.environment
  attributes    = compact(concat(var.attributes, ["alb", "access", "logs"]))
  tags          = var.tags
  force_destroy = var.alb_access_logs_s3_bucket_force_destroy
  enabled       = var.access_logs_enabled
  policy        = join("", data.aws_iam_policy_document.default.*.json)
}

resource "aws_lb" "default" {
  name               = module.naming.id
  tags               = module.naming.tags
  internal           = var.internal
  load_balancer_type = "application"

  security_groups = compact(
    concat(var.security_group_ids, [aws_security_group.default.id]),
  )

  subnets                          = var.subnet_ids
  enable_cross_zone_load_balancing = var.cross_zone_load_balancing_enabled
  enable_http2                     = var.http2_enabled
  idle_timeout                     = var.idle_timeout
  ip_address_type                  = var.ip_address_type
  enable_deletion_protection       = var.deletion_protection_enabled

  access_logs {
    bucket  = module.access_logs.bucket_id
    prefix  = var.access_logs_prefix
    enabled = var.access_logs_enabled
  }
}

# help with recreating of ALB target group
resource "random_id" "alb_tg" {
  byte_length = 8
  keepers = {
    name                 = var.target_group_name
    port                 = var.target_group_port
    protocol             = var.target_group_protocol
    vpc_id               = var.vpc_id
    target_type          = var.target_group_target_type
  }
}

resource "aws_lb_target_group" "default" {
  name                 = var.target_group_name == "" ? join(module.naming.delimiter, [module.naming.id,random_id.alb_tg.hex]) : var.target_group_name
  port                 = var.target_group_port
  protocol             = var.target_group_protocol
  vpc_id               = var.vpc_id
  target_type          = var.target_group_target_type
  deregistration_delay = var.deregistration_delay

  health_check {
    path                = var.health_check_path
    timeout             = var.health_check_timeout
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    interval            = var.health_check_interval
    matcher             = var.health_check_matcher
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    module.naming.tags,
    var.target_group_additional_tags
  )
}

resource "aws_lb_listener" "http_forward" {
  count             = var.http_enabled && var.http_redirect != true ? 1 : 0
  load_balancer_arn = aws_lb.default.arn
  port              = var.http_port
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.default.arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "http_redirect" {
  count             = var.http_enabled && var.http_redirect == true ? 1 : 0
  load_balancer_arn = aws_lb.default.arn
  port              = var.http_port
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.default.arn
    type             = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  count             = var.https_enabled ? 1 : 0
  load_balancer_arn = aws_lb.default.arn

  port            = var.https_port
  protocol        = "HTTPS"
  ssl_policy      = var.https_ssl_policy
  certificate_arn = var.certificate_arn

  default_action {
    target_group_arn = aws_lb_target_group.default.arn
    type             = "forward"
  }
}

data "aws_route53_zone" "selected" {
  count = var.r53_zone_name != "" && var.r53_record_name != "" ? 1 : 0
  name  = var.r53_zone_name # "test.com."
}

resource "aws_route53_record" "alb" {
  count   = var.r53_zone_name != "" && var.r53_record_name != "" ? 1 : 0
  zone_id = join("", data.aws_route53_zone.selected.*.zone_id)
  name    = var.r53_record_name
  type    = "A"

  alias {
    name                   = aws_lb.default.dns_name
    zone_id                = aws_lb.default.zone_id
    evaluate_target_health = true
  }
}