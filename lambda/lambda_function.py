import json
import os # for env variable set up
import boto3

def env_topic_arn():
    ssm = boto3.client('ssm')
    default_region = "eu-central-1"

    region = os.getenv('AWS_REGION', default_region)

    response = ssm.get_parameter(
        Name='accountID',
        WithDecryption=True
    )
    my_account_id = response['Parameter']['Value']
    my_topic_name = "my-notification-topic"
    topic_arn = f"arn:aws:sns:{region}:{my_account_id}:{my_topic_name}"
    
    return topic_arn

def lambda_handler(event, context):
    # Initialize the SNS client
    sns = boto3.client('sns')
    
    
    # Specify the ARN of SNS topic
    topic_arn = env_topic_arn()
    
    # Process each record from the S3 bucket event
    for record in event['Records']:
        bucket_name = record['s3']['bucket']['name']
        object_key = record['s3']['object']['key']
        size = record['s3']['object'].get('size', 0)  # Get size, default to 0 if not present
        
        # Create a message to send via SNS
        message = {
            'message': 'A new file has been uploaded.',
            'file_name': object_key,
            'bucket_name': bucket_name,
            'size': size
        }
        
        # Convert message dictionary to JSON format
        message_string = json.dumps(message)
        
        # Publish message to SNS
        response = sns.publish(
            TopicArn=topic_arn,
            Message=message_string,
            Subject='New File Uploaded to S3 Bucket'
        )
        
        print("SNS publish response:", response)

    return {
        'statusCode': 200,
        'body': json.dumps('Successfully processed S3 event.')
    }
