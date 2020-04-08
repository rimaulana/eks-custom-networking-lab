SHELL = /bin/bash

BUCKET_NAME = gresik
BUCKET_REGION = us-east-1



.PHONY: validate
validate:
	find . | grep yaml | xargs cfn-lint 

.PHONY: upload
upload:
	aws s3 sync templates s3://$(BUCKET_NAME)/eks/templates --region $(BUCKET_REGION)
