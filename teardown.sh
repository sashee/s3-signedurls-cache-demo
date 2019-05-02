BUCKETNAME=$(aws s3api list-buckets | jq -r '.Buckets[] | select(.Name | startswith("signedurls-truncate-test-")).Name')

aws s3 rm s3://$BUCKETNAME --recursive

aws s3api delete-bucket --bucket $BUCKETNAME
