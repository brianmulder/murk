output "private_ips" {
  value = {
    "dark"   = "${aws_instance.dark.*.private_ip}"
    "shine"  = "${aws_instance.shine.*.private_ip}",
    "bright" = "${aws_instance.bright.*.private_ip}",
    "burn"   = "${aws_instance.burn.*.private_ip}",
  }
}

output "public_ips" {
  sensitive = true
  value = {
    "dark"   = "${aws_instance.dark.*.public_ip}"
  }
}
