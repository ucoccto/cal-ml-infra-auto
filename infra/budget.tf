# 선택 사항: budget_email을 지정한 경우에만 AWS Budget을 만든다.
# 실제 청구 금액은 환율/세금/데이터 전송/추가 리소스에 따라 달라질 수 있으므로
# 예산 초과 방지의 보조 장치로 사용한다.
resource "aws_budgets_budget" "monthly" {
  count = var.budget_email != "" ? 1 : 0

  name         = "${var.project_name}-${var.environment}-monthly-budget"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # 예상 비용이 예산의 80%를 넘을 것으로 보이면 알림한다.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }

  # 실제 비용이 예산의 100%를 넘으면 다시 알림한다.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }
}
