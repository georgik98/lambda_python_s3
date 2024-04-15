import json
import boto3 # type: ignore

def lambda_handler(event, context):
    # Initialize the SNS client
    sns = boto3.client('sns')
    
    # Specify the ARN of SNS topic
    topic_arn = 'arn:aws:sns:eu-central-1:360980374647:my-notification-topic'
    
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
