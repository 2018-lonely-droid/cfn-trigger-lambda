import boto3
import json
import cfnresponse
from botocore.response import StreamingBody  # Import the StreamingBody class


lambda_client = boto3.client('lambda')


def lambda_handler(event, context):
    try:
        if event['RequestType'] == "Create":
            cfn_event = {}  # Ability to pass parameters

            # Invoke Lambda function and capture the response
            invoke_response = lambda_client.invoke(
                FunctionName='LambdaHelloWorld',
                InvocationType='Event',  # RequestResponse for synchronous invocation and Event for asychronous invocation
                Payload=json.dumps(cfn_event)
            )

            # Check if the invocation was successful: 200 for synchonous and 202 for asynchronous (meaning event queued)
            if invoke_response['StatusCode'] == 200 or invoke_response['StatusCode'] == 202:
                
                # Convert the dictionary to a new dictionary where the StreamingBody content is converted to a string
                serializable_dict = {}
                for key, value in invoke_response.items():
                    if isinstance(value, StreamingBody):
                        # If the value is a StreamingBody, read its content and convert to a string
                        content_str = value.read().decode('utf-8')
                        serializable_dict[key] = content_str
                    else:
                        # If not a StreamingBody, include as is
                        serializable_dict[key] = value
        
                # Convert the new dictionary to a JSON-formatted string
                responseValue = json.dumps(serializable_dict)

            else:
                responseValue = f"Lambda invocation failed with status code: {invoke_response['StatusCode']}"

        responseData = {'InvokedLambdaResponse': responseValue}
        cfnresponse.send(event, context, cfnresponse.SUCCESS, responseData, 'LambdaHelloWorld-customresource-id')

    except Exception as e:
        # Log the exception and include the error message in responseData
        print(f"Exception: {str(e)}")
        responseData = {'InvokedLambdaResponse': str(e)}
        cfnresponse.send(event, context, cfnresponse.FAILED, responseData, 'LambdaHelloWorld-customresource-id')