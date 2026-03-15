## Changelog

### v2.0.0 (2026-03-14)
- Added AWS multi-cloud support alongside existing Azure deployment
- New `modules/aws/` with network, compute, bastion, and monitoring submodules
- New `environments/aws/` root module wired to all AWS modules
- Reorganized Azure modules under `modules/azure/` and `environments/azure/` for consistency
- Added `Makefile` for single-command deploy to either cloud (`make azure` / `make aws`)
- Updated CI/CD pipeline to validate and tfsec-scan both Azure and AWS configurations
- Added GuardDuty, CloudWatch, and SNS alerting in AWS monitoring module
- Added cloud-init hardening for AWS EC2 instances (mirrors Azure VM hardening)
- Added `terraform.tfvars.example` for AWS environment
- Added screenshots: security alerts, syslog attack events, SOC workbook

### v1.0.0 (2026-02-24)
- Initial release
- Azure Sentinel deployment
- Log Analytics workspace
- Basic detection rules
- Conditional access policies