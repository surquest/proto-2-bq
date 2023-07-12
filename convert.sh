#!/bin/bash

# Define the base path
base_path="/tmp/schemas"

# Get the relative file path from the first parameter
relative_path="$1"

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
