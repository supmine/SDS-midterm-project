output "app_public_1_ip" {
  description = "The public IP address of the app instance"
  value       = aws_eip.public.public_ip
}
