#!/bin/bash
set -e

# Upload flash-attention-nova wheels to S3
BUCKET="lexiq-nova-wheels"
PREFIX="flash-attention-nova"

echo "📦 Uploading flash-attention-nova wheels to s3://${BUCKET}/${PREFIX}/"

for wheel in artifacts/dist/*.whl; do
    if [ -f "$wheel" ]; then
        filename=$(basename "$wheel")
        echo "  Uploading ${filename}..."
        aws s3 cp "$wheel" "s3://${BUCKET}/${PREFIX}/${filename}" --acl public-read
        echo "  ✅ Uploaded: s3://${BUCKET}/${PREFIX}/${filename}"
    fi
done

echo "✅ All flash-attention-nova wheels uploaded successfully"

