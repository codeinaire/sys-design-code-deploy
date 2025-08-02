exports.handler = async (event) => {
  console.log('Build Worker Lambda triggered')
  console.log('Event:', JSON.stringify(event, null, 2))

  // TODO: Implement build worker logic
  const response = {
    statusCode: 200,
    body: JSON.stringify({
      message: 'Build worker executed successfully',
      timestamp: new Date().toISOString(),
    }),
  }

  return response
}
