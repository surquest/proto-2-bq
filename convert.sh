#!/bin/bash

# Define the base path
base_path="/tmp/schemas"

# Define default values for arguments
proto=""
metadata=false

# Define function to print help
function print_help {
  echo "Usage: $0 --proto <path_to_proto> [--metadata <true/false>] [--help]"
  echo "  --proto <path_to_proto>   Path to the proto message specification"
  echo "  --metadata <true/false>   Add PubSub metadata columns (default: false)"
  echo "  --help                    Print this help message"
}

# Get arguments from the command line
while [[ $# -gt 0 ]]; do
    case "$1" in
        --proto)
        proto="$2"
        shift 2
        ;;
        --metadata)
        metadata="$2"
        shift 2
        ;;
        --help)
        print_help
        exit 0
        ;;
        *)
        echo "Unknown option: $1"
        print_help
        exit 1
        ;;
    esac
done

# Check if proto argument is provided
if [ -z "$proto" ]; then
  echo "Error: --proto argument is required"
  print_help
  exit 1
fi

# Check if metadata argument is true or false
if [ "$metadata" != "true" ] && [ "$metadata" != "false" ]; then
  echo "Error: --metadata argument must be true or false"
  print_help
  exit 1
fi

# Get table name as string from the first parameter before the dot
table_name=$(echo "$proto" | cut -d "." -f 1)

# Check if the first parameter is provided
if [ -z "$proto" ]; then
    echo "Error: No file path provided."
    exit 1
fi

# Combine base path and the passed first parameter
file_path="$base_path/$proto"

# Check if the file exists
if [ ! -f "$file_path" ]; then
    echo "Error: No file found at $file_path"
    exit 1
fi

# Create a copy of the file with the combined path
copied_file_path="${base_path}/copy.$proto"
cp "$file_path" "$copied_file_path"

# Substitute the first line of the copied file with the specified content
sed -i '1s/.*/syntax = "proto3";\npackage out;\nimport "bq_table.proto";\nimport "bq_field.proto";\n\nimport "google\/protobuf\/wrappers.proto";\nimport "google\/protobuf\/timestamp.proto";/' "$copied_file_path"

# Find the line number of the first occurrence of the word "message"
line_number=$(grep -n "message" "$copied_file_path" | head -n 1 | cut -d ":" -f 1)

# Add the specified text after the line with the message
sed -i "$((line_number+1))i\option (gen_bq_schema.bigquery_opts).table_name = \"$table_name\";" "$copied_file_path"

protoc --bq-schema_out=$base_path --proto_path=/tmp/default --proto_path=$base_path $copied_file_path

# Remove the copied file
rm $copied_file_path

# Check if the second parameter is not false
if [ "$metadata" != false ]; then
    # Define the new JSON array with Pub/Sub message metadata
    metadata_src='/tmp/default/metadata.json'
    
    # Read the existing metadata JSON array from the file
    metadata_json=$(cat $metadata_src)
    schema_json=$(cat $base_path/out/$table_name.schema)

    echo -e "$schema_json\n$metadata_json" | jq -s 'flatten(1)' \
      > $base_path/out/$table_name.schema 

fi

# print success and path the to the generated file
echo "---------------------------------------------------------------------------------------------------"
echo "-------------------------------------------- Success ----------------------------------------------"
echo "Generated file can be found in mounted volume:"
echo "./out/$table_name.schema"
echo "---------------------------------------------------------------------------------------------------"
echo "Note: feel free to happily ignore these warnings:"
echo "- copy.$1:4:1: warning: Import bq_field.proto is unused."
echo "- copy.$1:7:1: warning: Import google/protobuf/timestamp.proto is unused."
echo "- copy.$1:6:1: warning: Import google/protobuf/wrappers.proto is unused."
echo "---------------------------------------------------------------------------------------------------"