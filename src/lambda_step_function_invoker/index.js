const { SFNClient, StartExecutionCommand } = require('@aws-sdk/client-sfn')

const sfnClient = new SFNClient({ region: 'us-east-1' })

exports.handler = async (event) => {
  try {
    console.log('Event received:', JSON.stringify(event, null, 2))

    // Extract information from the event
    const { sourceBucket, sourceKey, destinationBuckets } = event

    if (!sourceBucket || !sourceKey || !destinationBuckets) {
      throw new Error('Missing required parameters: sourceBucket, sourceKey, destinationBuckets')
    }

    // Prepare the input for the Step Function
    const stepFunctionInput = {
      sourceBucket,
      sourceKey,
      destinationBuckets: Array.isArray(destinationBuckets)
        ? destinationBuckets
        : [destinationBuckets],
    }

    console.log('Step Function input:', JSON.stringify(stepFunctionInput, null, 2))

    // Get the Step Function ARN from environment variable or use a default
    const stateMachineArn =
      process.env.STEP_FUNCTION_ARN ||
      'arn:aws:states:us-east-1:000000000000:stateMachine:file-copy-workflow'

    // Start the Step Function execution
    const startExecutionCommand = new StartExecutionCommand({
      stateMachineArn,
      input: JSON.stringify(stepFunctionInput),
      name: `file-copy-${Date.now()}`, // Unique execution name
    })

    const result = await sfnClient.send(startExecutionCommand)

    console.log('Step Function execution started:', result)

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'Step Function execution started successfully',
        executionArn: result.executionArn,
        startDate: result.startDate,
        input: stepFunctionInput,
      }),
    }
  } catch (error) {
    console.error('Error invoking Step Function:', error)

    return {
      statusCode: 500,
      body: JSON.stringify({
        message: 'Error invoking Step Function',
        error: error.message,
      }),
    }
  }
}
