
output "rds_hostname" {
  value = "${aws_db_instance.db.address}"
}
output "rds_user" {
  value = "${var.db_user}"
}
output "rds_pass" {
  value = "${var.db_pass}"
}
output "rds_name" {
  value = "${var.db_name}"
}
output "elb_hostname" {
  value = "${aws_alb.main.dns_name}"
}



