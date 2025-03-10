output "cluster_name" {
  value = aws_eks_cluster.mahesh.name
}
output "cluster_id" {
  value = aws_eks_cluster.mahesh.id
}
output "node_grouop_id" {
  value = aws_eks_node_group.mahesh.id
}
output "vpc_id" {
  value = aws_vpc.mahesh_vpc.id
}
output "subnet_ids" {
  value = aws_subnet.mahesh_subnet[*].id
}