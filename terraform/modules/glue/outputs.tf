output "database_name" {
  description = "Name of the Glue catalog database"
  value       = aws_glue_catalog_database.telemetry.name
}

output "database_arn" {
  description = "ARN of the Glue catalog database"
  value       = "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:database/${aws_glue_catalog_database.telemetry.name}"
}

output "table_name" {
  description = "Name of the Glue catalog table for raw telemetry"
  value       = aws_glue_catalog_table.telemetry_raw.name
}

output "table_arn" {
  description = "ARN of the Glue catalog table"
  value       = "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${aws_glue_catalog_database.telemetry.name}/${aws_glue_catalog_table.telemetry_raw.name}"
}

output "crawler_name" {
  description = "Name of the Glue crawler"
  value       = aws_glue_crawler.telemetry.name
}

output "crawler_arn" {
  description = "ARN of the Glue crawler"
  value       = aws_glue_crawler.telemetry.arn
}
