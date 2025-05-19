import boto3
import json


def lambda_handler(event, context):
    print("Hello World")
    print("Event: " + json.dumps(event, indent=2))
    print("Context: " + str(context))

    # Here is where you could interact with various AWS services that were historically not fully supported by CloudFormation or had limitations.
    # Some examples are AWS Resource Groups and Tag Editor, AWS WAF (Web Application Firewall), AWS Certificate Manager Private Certificate Authority, etc. 