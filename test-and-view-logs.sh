#!/bin/bash

# Script to test lambda_build_worker and view logs
# This script tests the lambda and then shows you how to view logs

echo "🚀 Testing lambda_build_worker and showing log viewing options..."

# Test the lambda function locally first
echo ""
echo "🧪 Testing lambda function locally..."
node test-build-worker.js

echo ""
echo "📋 Now let's check the logs in LocalStack..."

# Check if LocalStack is running
if ! docker ps | grep -q localstack; then
    echo "❌ LocalStack is not running. Start it with: docker-compose up -d"
    exit 1
fi

echo "✅ LocalStack is running"

# Get the API Gateway URL
API_URL=$(cd terraform/infra && terraform output -raw api_gateway_url 2>/dev/null)

if [ -z "$API_URL" ]; then
    echo "⚠️  Could not get API Gateway URL. Make sure Terraform is applied."
    echo "   Run: cd terraform/infra && terraform apply"
else
    echo "📍 API Gateway URL: $API_URL"
    
    echo ""
    echo "🧪 Testing via API Gateway..."
    curl -X POST "${API_URL}/builds" \
      -H "Content-Type: application/json" \
      -d '{"commit": "test123"}' \
      -w "\nHTTP Status: %{http_code}\n" \
      -s
fi

echo ""
echo "🔍 LOG VIEWING OPTIONS:"
echo ""

echo "1️⃣  View LocalStack container logs:"
echo "   docker logs localstack"
echo ""

echo "2️⃣  View CloudWatch logs via AWS CLI:"
echo "   awslocal logs describe-log-groups --log-group-name-prefix '/aws/lambda/build-worker'"
echo ""

echo "3️⃣  View latest lambda logs:"
echo "   awslocal logs describe-log-streams \\"
echo "     --log-group-name '/aws/lambda/build-worker' \\"
echo "     --order-by LastEventTime \\"
echo "     --descending"
echo ""

echo "4️⃣  View specific log stream:"
echo "   awslocal logs get-log-events \\"
echo "     --log-group-name '/aws/lambda/build-worker' \\"
echo "     --log-stream-name 'STREAM_NAME'"
echo ""

echo "5️⃣  Follow logs in real-time:"
echo "   docker logs -f localstack"
echo ""

echo "6️⃣  LocalStack Web UI:"
echo "   Open http://localhost:8080 in your browser"
echo "   Navigate to CloudWatch > Logs"
echo ""

echo "🎯 Quick log viewing commands:"
echo ""

# Try to get logs automatically
echo "📊 Attempting to view recent logs..."
echo ""

# Check if log group exists
if awslocal logs describe-log-groups --log-group-name-prefix "/aws/lambda/build-worker" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "build-worker"; then
    echo "✅ Log group found. Getting recent logs..."
    
    # Get the most recent log stream
    LOG_STREAM=$(awslocal logs describe-log-streams \
      --log-group-name "/aws/lambda/build-worker" \
      --order-by LastEventTime \
      --descending \
      --query 'logStreams[0].logStreamName' \
      --output text 2>/dev/null)
    
    if [ "$LOG_STREAM" != "None" ] && [ -n "$LOG_STREAM" ]; then
        echo "📝 Latest log stream: $LOG_STREAM"
        echo ""
        echo "📋 Recent log events:"
        awslocal logs get-log-events \
          --log-group-name "/aws/lambda/build-worker" \
          --log-stream-name "$LOG_STREAM" \
          --query 'events[*].message' \
          --output text 2>/dev/null | head -20
    else
        echo "⚠️  No log streams found yet. Try invoking the lambda first."
    fi
else
    echo "⚠️  Log group not found yet. This usually means:"
    echo "   1. The lambda hasn't been invoked yet"
    echo "   2. Terraform hasn't been applied"
    echo "   3. LocalStack CloudWatch service isn't running"
    echo ""
    echo "💡 Try:"
    echo "   cd terraform/infra && terraform apply"
    echo "   Then invoke the lambda via API Gateway"
fi

echo ""
echo "🎯 Script complete! Use the commands above to view logs."
