output "bucket" {
  value = aws_s3_bucket.lake
}

output "encryption_key" {
  value = aws_kms_key.data_lake
}

output "paths" {
  value = {
    data : "s3://${aws_s3_bucket.lake.bucket}/data/",
    input : "s3://${aws_s3_bucket.lake.bucket}/input/",
  }
}
