data "aws_ami" "winserv2019" {
    most_recent = true
    owners = ["801119661308"]

    filter {
        name = "name"
        values = ["Windows_Server-2019-English-Full-Base-*"]
    }
}

data "aws_ami" "rhel9" {
    most_recent = true
    owners = ["309956199498"]

    filter {
        name = "name"
        values = ["RHEL-9.7*_HVM-*x86_64*"]
    }
}
