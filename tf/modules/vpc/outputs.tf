output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}

output "nat_instance_network_interface_id" {
  value = aws_instance.ec2_instance.primary_network_interface_id
}

output "igw_id" {
  value = aws_internet_gateway.igw.id
}
