variable "chart_data_bucket_name" {
  default = "notion-chart-data.com-sample"
}

variable "chart_site_bucket_name" {
  default = "notion-chart-site.com-sample"
}

variable "region" {
  default = "us-east-1"
}

variable "allowed_origins" {
  default = ["https://d1flvyqkje8uxg.cloudfront.net", "http://localhost:3000"]
}

# variable "domain_zone_id" {
#   default = "Z0199146Q0LSLV0HNGA0"
# }

# variable "domain_certificate_arn" {
#   default = "arn:aws:acm:us-east-1:260636397708:certificate/68ef103a-99b9-4980-82f2-ef3bbaf286e2"
# }