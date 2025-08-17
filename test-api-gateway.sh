#!/bin/bash

# Test script for the API Gateway /builds endpoint
# This script tests the API Gateway configuration and request validation

echo "🧪 Testing API Gateway /builds endpoint..."

# Get the API Gateway URL from Terraform output
API_URL=$(cd terraform/infra && terraform output -raw api_gateway_url 2>/dev/null)

if [ -z "$API_URL" ]; then
    echo "❌ Could not get API Gateway URL. Make sure Terraform is applied."
    exit 1
fi

echo "📍 API Gateway URL: $API_URL"

# Test 1: Valid request with commit
echo ""
echo "✅ Test 1: Valid request with commit"
curl -X POST "${API_URL}/builds" \
  -H "Content-Type: application/json" \
  -d '{"commit": "abc123"}' \
  -w "\nHTTP Status: %{http_code}\n" \
  -s

# Test 2: Missing commit field
echo ""
echo "❌ Test 2: Missing commit field (should fail validation)"
curl -X POST "${API_URL}/builds" \
  -H "Content-Type: application/json" \
  -d '{}' \
  -w "\nHTTP Status: %{http_code}\n" \
  -s

# Test 3: Wrong content type
echo ""
echo "❌ Test 3: Wrong content type (should fail validation)"
curl -X POST "${API_URL}/builds" \
  -H "Content-Type: text/plain" \
  -d '{"commit": "abc123"}' \
  -w "\nHTTP Status: %{http_code}\n" \
  -s

# Test 4: Empty body
echo ""
echo "❌ Test 4: Empty body (should fail validation)"
curl -X POST "${API_URL}/builds" \
  -H "Content-Type: application/json" \
  -w "\nHTTP Status: %{http_code}\n" \
  -s

echo ""
echo "🎯 Testing complete!"
echo ""
echo "Expected results:"
echo "- Test 1: Should return 200 OK (if lambda is working)"
echo "- Test 2-4: Should return 400 Bad Request (API Gateway validation)"
