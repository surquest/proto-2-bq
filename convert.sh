#!/bin/bash

# Define the base path
base_path="/tmp/schemas"

# Get the relative file path from the first parameter
relative_path="$1"

# Check if the second parameter (add message metadata) is provided (if not set to false)
if [ -z "$2" ]; then
    add_message_metadata=false
else
    add_message_metadata="$2"
fi


# Get table name as string from the first parameter before the dot
table_name=$(echo "$1" | cut -d "." -f 1)

# Check if the first parameter is provided
if [ -z "$1" ]; then
    echo "Error: No file path provided."
    exit 1
fi

# Combine base path and the passed first parameter
file_path="$base_path/$1"

# Check if the file exists
if [ ! -f "$file_path" ]; then
    echo "Error: File not found."
    exit 1
fi

# Create a copy of the file with the combined path
copied_file_path="${base_path}/copy.$1"
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

# Check if the second parameter is set to true
if [ "$add_message_metadata" = true ]; then
    # Define the new JSON array with Pub/Sub message metadata
    metadata='[
        {
            "name": "subscription_name",
            "type": "STRING",
            "mode": "NULLABLE",
            "description": "Name of a subscription"
        },
        {
            "name": "message_id",
            "type": "STRING",
            "mode": "NULLABLE",
            "description": "ID of a message"
        },
        {
            "name": "publish_time",
            "type": "TIMESTAMP",
            "mode": "NULLABLE",
            "description": "The time of publishing a message"
        },
        {
            "name": "attributes",
            "type": "JSON",
            "mode": "NULLABLE",
            "description": "A JSON object containing all message attributes. It also contains additional fields that are part of the Pub/Sub message including the ordering key, if present."
        }
    ]'

    # Read the existing JSON array from the file
    json_array=$(jq '.[]' $base_path/out/$table_name.schema)

    # Append the new JSON array to the existing array
    json_array=$(echo "$json_array" | jq --argjson metadata "$metadata" '. + $metadata')

    # Write the updated JSON array back to the file
    echo "$json_array" | jq '.' > $base_path/out/$table_name.schema
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
