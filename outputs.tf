output "alb_name" {
  description = "The ARN suffix of the ALB"
  value       = aws_lb.default.name
}

output "alb_arn" {
  description = "The ARN of the ALB"
  value       = aws_lb.default.arn
}

output "alb_arn_suffix" {
  description = "The ARN suffix of the ALB"
  value       = aws_lb.default.arn_suffix
}

output "alb_dns_name" {
  description = "DNS name of ALB"
  value       = aws_lb.default.dns_name
}

output "alb_zone_id" {
  description = "The ID of the zone which ALB is provisioned"
  value       = aws_lb.default.zone_id
}

output "security_group_id" {
  description = "The security group ID of the ALB"
  value       = aws_security_group.default.id
}

output "default_target_group_arn" {
  description = "The default target group ARN"
  value       = aws_lb_target_group.default.arn
}

output "http_listener_arn" {
  description = "The ARN of the HTTP forwarding listener"
  value       = join("", aws_lb_listener.http_forward.*.arn)
}

output "http_redirect_listener_arn" {
  description = "The ARN of the HTTP to HTTPS redirect listener"
  value       = join("", aws_lb_listener.http_redirect.*.arn)
}

output "https_listener_arn" {
  description = "The ARN of the HTTPS listener"
  value       = join("", aws_lb_listener.https.*.arn)
}

output "listener_arns" {
  description = "A list of all the listener ARNs"
  value = compact(
    concat(aws_lb_listener.http_forward.*.arn, aws_lb_listener.http_redirect.*.arn, aws_lb_listener.https.*.arn)
  )
}

output "access_logs_bucket_id" {
  description = "The S3 bucket ID for access logs"
  value       = module.access_logs.bucket_id
}

output "r53_fqdn" {
  description = "FQDN for the r53 record"
  value       = var.r53_zone_name != "" && var.r53_record_name != "" ? join("", aws_route53_record.alb.*.fqdn) : "no record created"
}
