provider "aws" {
  region = "eu-west-2"
}

module "vpc" {
  source                      = "git::https://github.com/MagnetarIT/terraform-aws-vpc.git?ref=tags/0.1.0"
  cidr_block                  = "10.255.0.0/16"
  namespace                   = "mag"
  environment                 = "test"
  name                        = "vpc"
  create_aws_internet_gateway = true
}

module "subnets" {
  source             = "git::https://github.com/MagnetarIT/terraform-aws-subnets.git?ref=tags/0.1.0"
  namespace          = "mag"
  environment        = "dev"
  name               = "app"
  vpc_id             = module.vpc.vpc_id
  igw_id             = module.vpc.igw_id
  cidr_block         = "10.255.0.0/22"
  max_subnet_count   = 3
  availability_zones = list("eu-west-2a", "eu-west-2b", "eu-west-2c", )
}

module "alb" {
  source                                  = "../"
  namespace                               = "mag"
  environment                             = "test"
  name                                    = "app"
  vpc_id                                  = module.vpc.vpc_id
  subnet_ids                              = module.subnets.public_subnet_ids
  alb_access_logs_s3_bucket_force_destroy = true
  #r53_record_name                         = "alb.magnetar.it"
  #r53_zone_name                           = "magnetar.it"
}

