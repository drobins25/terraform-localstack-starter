resource "aws_sns_topic" "events" {
  name = "${var.project}-${var.env}-events"
}

resource "aws_sns_topic_subscription" "events_to_jobs" {
  topic_arn = aws_sns_topic.events.arn
  protocol = "sqs"
  endpoint = aws_sqs_queue.jobs.arn
}

output "sns_topic_arn" {
  value = aws_sns_topic.events.arn
}
