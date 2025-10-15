resource "aws_sqs_queue" "dlq" {
  name = "${var.project}-${var.env}-dlq"
}

resource "aws_sqs_queue" "jobs" {
  name = "${var.project}-${var.env}-jobs"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 5
  })
}

output "sqs_jobs_name" { value = aws_sqs_queue.jobs.name }
output "sqs_dlq_name"  { value = aws_sqs_queue.dlq.name }
