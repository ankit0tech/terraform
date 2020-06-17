provider "aws" {
  region="ap-south-1"
  profile="Ankitprofile"
}

resource "aws_key_pair" "keygen" {
  key_name   = "mysecondoskey"
  public_key = file("C:/Users/dell/Desktop/tera/mytest/mykey.pub")
}

resource "aws_security_group" "sg" {
  name        = "mysecuritygroup"
  description = "Allow Traffic from port number 80 for http protocol"
  vpc_id      = "vpc-9a405cf2"

  ingress {
    description = "Allow traffic for HTTP port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
	description = "Allowing SSH"
	from_port   = 22
	to_port     = 22
	protocol    = "tcp"
	cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
	Name = "mysecuritygroup"
  }
}

resource "aws_ebs_volume" "pendrive1" {
  availability_zone = aws_instance.myos.availability_zone
  size              = 1

  tags = {
    Name = "pendrive"
  }
}

resource "aws_volume_attachment" "attach" {
  depends_on = [
		aws_ebs_volume.pendrive1,	
		aws_instance.myos,
	]
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.pendrive1.id
  instance_id = aws_instance.myos.id
  force_detach = true
}


resource "aws_instance" "myos" {
  ami="ami-0447a12f28fddb066"
  instance_type="t2.micro"
  key_name= aws_key_pair.keygen.key_name
  security_groups=[ aws_security_group.sg.name ]
  
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/dell/Desktop/tera/mytest/mykey")
    host     = aws_instance.myos.public_ip
  }

  provisioner "remote-exec" {
    inline = [  
      "sudo yum install httpd php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }  
  
  tags = {
    Name = "TeraOS1"
  }  
  
}


resource "null_resource" "clone"  {


	depends_on = [
		aws_volume_attachment.attach,	
	]

	connection {
		type     = "ssh"
		user     = "ec2-user"
		private_key = file("C:/Users/dell/Desktop/tera/mytest/mykey")
		host     = aws_instance.myos.public_ip
	}

  provisioner "remote-exec" {
	inline  = [
		"sudo mkfs.ext4 /dev/xvdh -y",
		"sudo mount /dev/xvdh /var/www/html",
		"sudo rm -rf /var/www/html/*",
		"sudo git clone https://github.com/ankit0tech/hello-world.git /var/www/html/",
	]
  }
}

resource "aws_s3_bucket" "mybucket" {
  bucket = "bucky-101-bucket"
  acl    = "public-read"
  force_destroy = "true"
  versioning {
    enabled = true
  }
  tags = {
    Name        = "My bucket"

  }
}


resource "aws_s3_bucket_object" "bucketobj" {
  depends_on = [
	aws_s3_bucket.mybucket,
  ]
  bucket = aws_s3_bucket.mybucket.bucket
  key = "dog.png"
  acl ="public-read"
  content_type = "image/jpg"
  source = "C:/Users/dell/Desktop/dog.png"

}


resource "aws_cloudfront_distribution" "s3_cloud_front" {
  origin {
    domain_name = "bucky-101-bucket.s3.amazonaws.com"
    origin_id   = "my_s3_bucket"
	
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Bucket for just one image !!!"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "my_s3_bucket"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "my_s3_bucket"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "my_s3_bucket"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE","IN"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/dell/Desktop/tera/mytest/mykey")
    host     = aws_instance.myos.public_ip
  }

  provisioner "remote-exec" {
    inline = [  
      "sudo su << EOF",
      "echo \"<center><img src='http://${aws_cloudfront_distribution.s3_cloud_front.domain_name}/dog.png' height='300px' width='300px'></center>\" >> /var/www/html/index.html",
      "EOF"
    ]
  }  
  
}

resource "null_resource" "local" {
	depends_on = [
		aws_cloudfront_distribution.s3_cloud_front,	
	]
	provisioner "local-exec" {
		command = "start chrome ${aws_instance.myos.public_ip}"
	}
}
