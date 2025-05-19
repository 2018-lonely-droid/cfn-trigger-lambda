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