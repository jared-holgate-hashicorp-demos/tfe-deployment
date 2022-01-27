resource "aws_lb" "tfe" {
  name               = "${var.friendly_name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.friendly_name_prefix}-alb"
  }
}

resource "aws_lb_target_group" "tfe" {
  name     = "${var.friendly_name_prefix}-tfe-tg"
  port     = var.create_hello_world ? 80 : 443
  protocol = var.create_hello_world ? "HTTP" : "HTTPS"
  vpc_id   = aws_vpc.main.id

  tags = {
    Name = "${var.friendly_name_prefix}-alb-target-group"
  }
}

resource "aws_lb_target_group" "replicated" {
  name     = "${var.friendly_name_prefix}-rep-tg"
  port     = 8800
  protocol = "HTTPS"
  vpc_id   = aws_vpc.main.id

  tags = {
    Name = "${var.friendly_name_prefix}-alb-target-group"
  }
}

resource "aws_lb_target_group_attachment" "tfe" {
  count            = var.create_hello_world ? 2 : 1
  target_group_arn = aws_lb_target_group.tfe.arn
  target_id        = aws_instance.tfe[count.index].id
  port             = var.create_hello_world ? 80 : 443
}

resource "aws_lb_target_group_attachment" "replicated" {
  count            = 1
  target_group_arn = aws_lb_target_group.replicated.arn
  target_id        = aws_instance.tfe[count.index].id
  port             = 8800
}

resource "aws_acm_certificate" "tfe" {
  domain_name       = "tfe.hashicorpdemo.net"
  validation_method = "DNS"

  tags = {
    Name = "tfe.hashicorpdemo.net"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "replicated" {
  domain_name       = "replicated.hashicorpdemo.net"
  validation_method = "DNS"

  tags = {
    Environment = "replicated.hashicorpdemo.net"
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "cloudflare_zone" "tfe" {
  name = "hashicorpdemo.net"
}

resource "cloudflare_record" "tfe_cert" {
  zone_id = data.cloudflare_zone.tfe.id
  name    = tolist(aws_acm_certificate.tfe.domain_validation_options)[0].resource_record_name
  value   = trimsuffix(tolist(aws_acm_certificate.tfe.domain_validation_options)[0].resource_record_value, ".")
  type    = tolist(aws_acm_certificate.tfe.domain_validation_options)[0].resource_record_type
  ttl     = 3600
}

resource "cloudflare_record" "tfe" {
  zone_id = data.cloudflare_zone.tfe.id
  name    = "tfe.hashicorpdemo.net"
  value   = aws_lb.tfe.dns_name
  type    = "CNAME"
  ttl     = 3600
}

resource "cloudflare_record" "replicated_cert" {
  zone_id = data.cloudflare_zone.tfe.id
  name    = tolist(aws_acm_certificate.replicated.domain_validation_options)[0].resource_record_name
  value   = trimsuffix(tolist(aws_acm_certificate.replicated.domain_validation_options)[0].resource_record_value, ".")
  type    = tolist(aws_acm_certificate.replicated.domain_validation_options)[0].resource_record_type
  ttl     = 3600
}

resource "cloudflare_record" "replicated" {
  zone_id = data.cloudflare_zone.tfe.id
  name    = "replicated.hashicorpdemo.net"
  value   = aws_lb.tfe.dns_name
  type    = "CNAME"
  ttl     = 3600
}

resource "aws_lb_listener" "tfe" {
  load_balancer_arn = aws_lb.tfe.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.tfe.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tfe.arn
  }
}

resource "aws_lb_listener" "replicated" {
  load_balancer_arn = aws_lb.tfe.arn
  port              = "8800"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.replicated.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.replicated.arn
  }
}

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.tfe.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}