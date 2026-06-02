output "db_private_ip" {
  value       = google_sql_database_instance.mysql_instance.private_ip_address
  description = "The allocated private IP address of the Cloud SQL MySQL instance"
}

output "memcached_node_ips" {
  value       = google_memcache_instance.memcached.memcache_nodes[*].host
  description = "The list of allocated private IP addresses for the Memcached nodes"
}