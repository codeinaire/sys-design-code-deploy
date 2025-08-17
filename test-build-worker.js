#!/usr/bin/env node

// Test script for the lambda_build_worker function
const { handler } = require('./src/lambda_build_worker/index.js')

// Mock event for testing
const testEvent = {
  body: JSON.stringify({
    commit: 'abc123',
  }),
}

console.log('Testing lambda_build_worker with event:', JSON.stringify(testEvent, null, 2))

// Test the handler
handler(testEvent)
  .then((result) => {
    console.log('✅ Lambda execution successful:')
    console.log(JSON.stringify(result, null, 2))
  })
  .catch((error) => {
    console.error('❌ Lambda execution failed:')
    console.error(error)
  })
