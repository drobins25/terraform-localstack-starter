# ── Scheduled: rate(1 minute) → SQS ────────────────────────────────────────────
resource "aws_cloudwatch_event_rule" "every_min" {
  name                = "${var.project}-${var.env}-every-min"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "every_min_to_jobs" {
  rule      = aws_cloudwatch_event_rule.every_min.name
  target_id = "sendToJobsEachMinute"
  arn       = aws_sqs_queue.jobs.arn
  # Static payload so you can recognize scheduler messages
  input     = jsonencode({ source = "scheduler", msg = "hello from EventBridge schedule" })
}

# ── On-demand: match events with source "demo.test" → SQS ──────────────────────
resource "aws_cloudwatch_event_rule" "on_demo_event" {
  name          = "${var.project}-${var.env}-on-demo"
  event_pattern = jsonencode({
    "source": ["demo.test"]
  })
}

resource "aws_cloudwatch_event_target" "on_demo_to_jobs" {
  rule      = aws_cloudwatch_event_rule.on_demo_event.name
  target_id = "sendToJobsOnDemo"
  arn       = aws_sqs_queue.jobs.arn
}

# ── Allow EventBridge service to send messages to the queue ────────────────────
resource "aws_sqs_queue_policy" "jobs_policy" {
  queue_url = aws_sqs_queue.jobs.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid: "AllowEventsToSend",
      Effect: "Allow",
      Principal: { Service: "events.amazonaws.com" },
      Action: "sqs:SendMessage",
      Resource: aws_sqs_queue.jobs.arn
    }]
  })
}
