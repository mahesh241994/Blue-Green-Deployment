provider "aws" {
  region = "ap-south-1"

}

resource "aws_vpc" "mahesh_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "mahesh-vpc"
  }
}

resource "aws_subnet" "mahesh_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.mahesh_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.mahesh_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["ap-south-1a", "ap-south-1b"], count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "mahesh-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "mahesh_igw" {
  vpc_id = aws_vpc.mahesh_vpc.id
  tags = {
    Name = "mahesh-igw"
  }
}

resource "aws_route_table" "mahesh_route_table" {
  vpc_id = aws_vpc.mahesh_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mahesh_igw.id
  }
  tags = {
    Name = "mahesh-route-table"
  }
}

resource "aws_route_table_association" "a" {
  count          = 2
  subnet_id      = element(aws_subnet.mahesh_subnet[*].id, count.index)
  route_table_id = aws_route_table.mahesh_route_table.id
}

resource "aws_security_group" "mahesh_cluster_sg" {
  vpc_id = aws_vpc.mahesh_vpc.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "mahesh-cluster-sg"
  }
}

resource "aws_security_group" "mahesh_node_group_sg" {
  vpc_id = aws_vpc.mahesh_vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "mahesh-node-group-sg"
  }
}

resource "aws_eks_cluster" "mahesh" {
  name     = "mahesh-cluster"
  role_arn = aws_iam_role.mahesh_cluster_eksrole.arn
  vpc_config {
    subnet_ids         = aws_subnet.mahesh_subnet[*].id
    security_group_ids = [aws_security_group.mahesh_cluster_sg.id]
  }
}

resource "aws_eks_node_group" "mahesh" {
  cluster_name    = aws_eks_cluster.mahesh.name
  node_group_name = "mahesh-node-group"
  node_role_arn   = aws_iam_role.mahesh_eks_node_role.arn
  subnet_ids      = aws_subnet.mahesh_subnet[*].id
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
  instance_types = ["t2.medium"]
  remote_access {
    ec2_ssh_key               = var.ssh_key
    source_security_group_ids = [aws_security_group.mahesh_node_group_sg.id]
  }
  tags = {
    Name = "mahesh-node-group"
  }
}

resource "aws_iam_role" "mahesh_cluster_eksrole" {
  name               = "mahesh-eks-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "mahesh_cluster_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.mahesh_cluster_eksrole.name
}

resource "aws_iam_role" "mahesh_eks_node_role" {
  name               = "mahesh-eks-node-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
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

resource "aws_iam_role_policy_attachment" "mahesh_node_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.mahesh_eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "mahesh_cni_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.mahesh_eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "mahesh_registry_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.mahesh_eks_node_role.name
}
