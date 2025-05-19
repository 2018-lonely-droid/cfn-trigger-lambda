#!/bin/bash

# Function to handle errors
handle_error() {
  local exit_code=$?
  local line_number=$1
  local stack_name=$2
  echo "Error occurred on line $line_number for stack $stack_name, command: $BASH_COMMAND"
  if [ $exit_code -ne 0 ]; then
    echo "Error message: $(AWS_PAGER="" aws cloudformation describe-stacks --stack-name "$stack_name" --region "$AWS_REGION" 2>&1)"
  fi
  exit $exit_code
}

# Set up error handling
trap 'handle_error $LINENO' ERR

######## Constants ########
# Set your AWS region
AWS_REGION="us-east-1"

# Set the stack names
STACK_1="lambdaCodeS3BucketCreate"
STACK_2="cfnLambdaTrigger"

######## Zip Lambda Functions ########
# Create a directory for storing the zipped files
ZIPS_DIR="lambda/zips"
mkdir -p "$ZIPS_DIR"

# Change to the lambda directory
cd lambda

# List and process Python files in the /lambda folder (excluding folders, customLambdaInvokerTrigger.py, and already zipped files)
for file in *.py; do
  [ -f "$file" ] || continue  # Skip folders and non-files
  [ "$file" == "customLambdaInvokerTrigger.py" ] && continue
  base_name=$(basename -- "$file" .py)
  zip -j "../$ZIPS_DIR/$base_name.zip" "$file"
done

######## Download and Configure Dependencies for customLambdaInvokerTrigger ########
# Create a directory for the deployment package
DEPLOYMENT_PACKAGE="deploymentPackage"

# Install required dependencies using pip in the deploymentPackage directory
cd "$DEPLOYMENT_PACKAGE"

# Create a virtual environment
python3 -m venv venv

# Activate the virtual environment
source venv/bin/activate

# Install required dependencies using pip in the virtual environment
pip install -r requirements.txt

# Deactivate the virtual environment
deactivate

# Set the path to the temporary directory
TMP_DIR="/tmp/site-packages-temp"

# Set the path to the Python binary
PYTHON_VERSION=$(basename $(readlink "venv/bin/python"))

# Set the path to the temporary directory and create
TMP_DIR="/tmp/site-packages-temp"
mkdir -p "$TMP_DIR"

# Copy customLambdaInvokerTrigger.py and the contents of site-packages to the temporary directory
cp "../customLambdaInvokerTrigger.py" "$TMP_DIR/"
cp -r "venv/lib/$PYTHON_VERSION/site-packages/" "$TMP_DIR/"

# Change to the temporary directory
cd "$TMP_DIR"

# Zip all the contents of the site-packages directory into customLambdaInvokerTrigger.zip
zip -r customLambdaInvokerTrigger.zip ./*

# Navigate back to the original directory
cd -

# Move the zip file to the desired location
mv "$TMP_DIR/customLambdaInvokerTrigger.zip" "../zips"

# Clean up the temporary directory
rm -rf "$TMP_DIR"

# Get back to main folder
cd ../../

######## Deploy Stack 1 & Stack 2 ########
# Use AWS CLI to deploy CloudFormation stack and wait for completion
aws cloudformation deploy \
  --stack-name "$STACK_1" \
  --template-file "lambdaCodeS3BucketCreate.yaml" \
  --capabilities CAPABILITY_IAM \
  --region "$AWS_REGION"

# Wait for CloudFormation stack creation and S3 bucket creation to complete
aws cloudformation wait stack-create-complete --stack-name "$STACK_1" --region "$AWS_REGION"

# Get the S3 bucket name from the stack outputs
BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name "$STACK_1" --query "Stacks[0].Outputs[0].OutputValue" --output text --region "$AWS_REGION")

# Upload zipped files to the S3 bucket and wait for the transfer to complete
aws s3 cp "$ZIPS_DIR/" "s3://$BUCKET_NAME/" --recursive --region "$AWS_REGION" && \

echo "Deployment complete for $STACK_1. S3 Bucket Name: $BUCKET_NAME"

# Use AWS CLI to deploy CloudFormation stack
aws cloudformation deploy \
  --stack-name "$STACK_2" \
  --template-file "cfnLambdaTrigger.yaml" \
  --capabilities CAPABILITY_IAM \
  --region "$AWS_REGION"

# Wait for CloudFormation stack creation
aws cloudformation wait stack-create-complete --stack-name "$STACK_2" --region "$AWS_REGION"
  
echo "Deployment complete for $STACK_2"