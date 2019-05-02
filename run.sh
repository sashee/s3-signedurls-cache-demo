npm ci

BUCKETNAME=$(aws s3api list-buckets | jq -r '.Buckets[] | select(.Name | startswith("signedurls-truncate-test-")).Name')

BUCKETNAME=$BUCKETNAME node index.js
