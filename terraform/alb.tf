# Application Load Balancer
resource "aws_lb" "wbo_alb" {
  name               = "wbo-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  enable_deletion_protection = false
  enable_http2              = true

  tags = {
    Name        = "wbo-alb"
    Environment = var.environment
  }
}

# Target Group for WBO containers
resource "aws_lb_target_group" "wbo_tg" {
  name        = "wbo-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.wbo_vpc.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-299"
  }

  deregistration_delay = 30

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  tags = {
    Name        = "wbo-tg"
    Environment = var.environment
  }
}

# ALB Listener (HTTP)
resource "aws_lb_listener" "wbo_http" {
  load_balancer_arn = aws_lb.wbo_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wbo_tg.arn
  }
}

# Optional: HTTPS Listener (uncomment when you have SSL certificate)
# resource "aws_lb_listener" "wbo_https" {
#   load_balancer_arn = aws_lb.wbo_alb.arn
#   port              = "443"
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   certificate_arn   = var.ssl_certificate_arn
#
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.wbo_tg.arn
#   }
# }
