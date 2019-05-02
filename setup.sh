BUCKETNAME=signedurls-truncate-test-$(date +%s)

aws --region us-east-1 s3api create-bucket --bucket $BUCKETNAME

curl -s $(curl -s https://api.thecatapi.com/v1/images/search | jq -r '.[0].url') --output cat.jpg
aws s3 cp cat.jpg s3://$BUCKETNAME/
rm cat.jpg
