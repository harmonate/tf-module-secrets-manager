# tf-modules-secrets-manager

```hcl
module "secrets-manager" {
  source                = "git::https://github.com/harmonate/tf-module-secrets-manager.git?ref=main"
  secret_name           = "my-secret"
  username              = "admin"
  rotation_days         = 30  #set to 0 to disable rotation
  cognito_user_pool_arn = "my-user-pool"  #optional for rotation a cognito user
  rds_db_instance_arn   = "my-db-instance-arn" #optional for rotation of db user creds
  only_rotate_secret    = true #if neither cognito nor rds, just rotate the secret
}
```
