### Creates a default (main) route table and default (main) NACL
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  tags = merge(
    var.default_tags,
    {
      Name = "terraform-vpc-${var.stack_name}"
    },
  )
}

resource "aws_internet_gateway" "internet-gw" {
  vpc_id = aws_vpc.main.id
  tags = merge(
    var.default_tags,
    {
      Name = "terraform-vpc-igw-${var.stack_name}"
    },
  )
}

resource "aws_route_table" "this" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gw.id
  }
  tags = merge(
    var.default_tags,
    {
      Name = "custom-routetable-${var.stack_name}"
    },
  )
}

resource "aws_subnet" "public_subnet" {
  # If you do not explictly state which route table the subnet is associated with,
  # it will be associated with the default route table.
  count                   = length(var.list_of_azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.list_of_cidr_range[count.index]
  availability_zone       = var.list_of_azs[count.index]
  map_public_ip_on_launch = true
  tags = merge(
    var.default_tags,
    {
      Name = format("terraform_public_subnet_%s", (count.index + 1))
    },
  )
}

resource "aws_route_table_association" "public" {
  count          = length(var.list_of_azs)
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.this.id
}