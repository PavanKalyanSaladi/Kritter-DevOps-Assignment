import json
import boto3
import base64
import uuid
import os
from datetime import datetime

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """
    Lambda function to handle file uploads to S3
    """
    
    # Get bucket name from environment variable
    bucket_name = os.environ.get('BUCKET_NAME')
    
    if not bucket_name:
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'S3 bucket name not configured'
            })
        }
    
    try:
        # Parse the incoming request
        if event.get('isBase64Encoded', False):
            body = base64.b64decode(event['body'])
        else:
            body = event['body']
        
        # Get headers
        headers = event.get('headers', {})
        content_type = headers.get('content-type', headers.get('Content-Type', 'application/octet-stream'))
        
        # Generate unique filename
        timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
        file_id = str(uuid.uuid4())[:8]
        
        # Determine file extension based on content type
        extension = 'bin'  # default
        if 'image/jpeg' in content_type:
            extension = 'jpg'
        elif 'image/png' in content_type:
            extension = 'png'
        elif 'text/plain' in content_type:
            extension = 'txt'
        elif 'application/pdf' in content_type:
            extension = 'pdf'
        elif 'application/json' in content_type:
            extension = 'json'
        
        filename = f"uploads/{timestamp}_{file_id}.{extension}"
        
        # Validate file size (max 10MB)
        if isinstance(body, str):
            body = body.encode('utf-8')
        
        if len(body) > 10 * 1024 * 1024:  # 10MB limit
            return {
                'statusCode': 413,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'File too large. Maximum size is 10MB.'
                })
            }
        
        # Upload to S3
        s3_client.put_object(
            Bucket=bucket_name,
            Key=filename,
            Body=body,
            ContentType=content_type,
            Metadata={
                'upload-timestamp': timestamp,
                'file-id': file_id,
                'original-size': str(len(body))
            }
        )
        
        # Log successful upload
        print(f"Successfully uploaded file: {filename} to bucket: {bucket_name}")
        print(f"File size: {len(body)} bytes")
        print(f"Content type: {content_type}")
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'File uploaded successfully',
                'filename': filename,
                'bucket': bucket_name,
                'size': len(body),
                'upload_id': file_id,
                'timestamp': timestamp
            })
        }
        
    except Exception as e:
        print(f"Error uploading file: {str(e)}")
        
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': f'Upload failed: {str(e)}'
            })
        }