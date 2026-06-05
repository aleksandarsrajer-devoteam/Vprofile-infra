output "workload_identity_provider" {
  value       = google_iam_workload_identity_pool_provider.github.name
  description = "Full provider resource name — add this as GitHub Secret: WIF_PROVIDER"
}

output "service_account_email" {
  value       = google_service_account.github_actions_sa.email
  description = "SA email — add this as GitHub Secret: GH_ACTIONS_SA"
}
