const AWS = require('aws-sdk')
const axios = require('axios')

// Configure AWS SDK for LocalStack
const s3 = new AWS.S3({
  endpoint: 'http://localhost:4566',
  s3ForcePathStyle: true,
  accessKeyId: 'test',
  secretAccessKey: 'test',
  region: 'us-east-1',
})

exports.handler = async (event) => {
  console.log('Build Worker Lambda triggered')
  console.log('Event:', JSON.stringify(event, null, 2))

  try {
    // Parse the request body
    let body
    if (event.body) {
      body = JSON.parse(event.body)
    } else {
      throw new Error('Request body is missing')
    }

    // Extract the commit value from the request body
    const { commit } = body
    if (!commit) {
      throw new Error('Commit value is missing from request body')
    }

    console.log(`Processing build request for commit: ${commit}`)

    // Download file from local file server
    const fileUrl = `http://host.docker.internal:3000/${commit}`
    console.log(`Downloading file from: ${fileUrl}`)

    const response = await axios({
      method: 'GET',
      url: fileUrl,
      responseType: 'arraybuffer',
      timeout: 30000, // 30 second timeout
      headers: {
        'User-Agent': 'Lambda-Build-Worker/1.0',
      },
    })

    if (response.status !== 200) {
      throw new Error(`Failed to download file. Status: ${response.status}`)
    }

    const fileBuffer = Buffer.from(response.data)
    const fileName = `${commit}.zip` // Assuming the file is a zip file
    const contentType = response.headers['content-type'] || 'application/octet-stream'

    console.log(
      `File downloaded successfully. Size: ${fileBuffer.length} bytes, Content-Type: ${contentType}`
    )

    // Upload file to global-builds S3 bucket
    const uploadParams = {
      Bucket: 'global-builds',
      Key: fileName,
      Body: fileBuffer,
      ContentType: contentType,
      Metadata: {
        commit: commit,
        'uploaded-by': 'lambda-build-worker',
        'upload-timestamp': new Date().toISOString(),
      },
    }

    console.log(`Uploading file to S3 bucket: global-builds/${fileName}`)
    const uploadResult = await s3.upload(uploadParams).promise()

    console.log(`File uploaded successfully to S3: ${uploadResult.Location}`)

    const response_body = {
      statusCode: 200,
      body: JSON.stringify({
        message: 'Build processed successfully',
        commit: commit,
        fileName: fileName,
        fileSize: fileBuffer.length,
        s3Location: uploadResult.Location,
        timestamp: new Date().toISOString(),
      }),
    }

    return response_body
  } catch (error) {
    console.error('Error processing build request:', error)

    const errorResponse = {
      statusCode: 500,
      body: JSON.stringify({
        message: 'Error processing build request',
        error: error.message,
        timestamp: new Date().toISOString(),
      }),
    }

    return errorResponse
  }
}
