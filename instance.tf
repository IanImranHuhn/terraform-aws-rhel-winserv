resource "aws_instance" "winserv2019" {
    ami = data.aws_ami.winserv2019.id
    instance_type = "t2.micro"
    key_name = "terraform-key"
    subnet_id = aws_subnet.shared_subnet.id
    vpc_security_group_ids = [aws_security_group.allow_all.id]

    tags = {
        Name = "WindowsServer2019"
    }
}

resource "aws_instance" "rhel9" {
    ami = data.aws_ami.rhel9.id
    instance_type = "t2.micro"
    key_name = "terraform-key"
    subnet_id = aws_subnet.shared_subnet.id
    vpc_security_group_ids = [aws_security_group.allow_all.id]

        tags = {
        Name = "RHEL9.7"
    }
}
