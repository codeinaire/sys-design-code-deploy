const { SFNClient, StartExecutionCommand } = require('@aws-sdk/client-sfn')
const { S3Client, GetObjectCommand } = require('@aws-sdk/client-s3')

const sfnClient = new SFNClient({ region: 'us-east-1' })
const s3Client = new S3Client({ region: 'us-east-1' })

exports.handler = async (event) => {
  try {
    console.log('S3 Event received:', JSON.stringify(event, null, 2))

    // Extract S3 event information
    const s3Event = event.Records[0].s3
    const bucketName = s3Event.bucket.name
    const objectKey = decodeURIComponent(s3Event.object.key.replace(/\+/g, ' '))

    console.log(`Processing file: ${objectKey} from bucket: ${bucketName}`)

    // Define destination buckets for replication
    const destinationBuckets = ['region-a-builds', 'region-b-builds']

    // Prepare input for Step Function
    const stepFunctionInput = {
      sourceBucket: bucketName,
      sourceKey: objectKey,
      destinationBuckets: destinationBuckets,
    }

    console.log('Step Function input:', JSON.stringify(stepFunctionInput, null, 2))

    // Get the Step Function ARN from environment variable
    const stateMachineArn = process.env.STEP_FUNCTION_ARN

    if (!stateMachineArn) {
      throw new Error('STEP_FUNCTION_ARN environment variable is not set')
    }

    // Start the Step Function execution
    const startExecutionCommand = new StartExecutionCommand({
      stateMachineArn,
      input: JSON.stringify(stepFunctionInput),
      name: `file-distribution-${Date.now()}-${objectKey.replace(/[^a-zA-Z0-9]/g, '-')}`,
    })

    const result = await sfnClient.send(startExecutionCommand)

    console.log('Step Function execution started:', result)

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'File distribution workflow started successfully',
        executionArn: result.executionArn,
        startDate: result.startDate,
        sourceBucket: bucketName,
        sourceKey: objectKey,
        destinationBuckets: destinationBuckets,
      }),
    }
  } catch (error) {
    console.error('Error processing S3 event:', error)

    return {
      statusCode: 500,
      body: JSON.stringify({
        message: 'Error processing S3 event',
        error: error.message,
      }),
    }
  }
}
