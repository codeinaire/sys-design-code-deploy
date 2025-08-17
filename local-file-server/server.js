// Simple local file server for exposing files over HTTP
// Usage:
//   FILE_SERVER_BASE_DIR=/path/to/files FILE_SERVER_PORT=3000 node local-file-server/server.js
// Optional auth:
//   FILE_SERVER_TOKEN=some-secret FILE_SERVER_BASE_DIR=/path node local-file-server/server.js
//
// In LocalStack/AWS Lambda, access via:
//   http://host.docker.internal:3000/files/<filename>

const http = require('http')
const fs = require('fs')
const fsp = require('fs/promises')
const path = require('path')

const port = Number(process.env.FILE_SERVER_PORT || 3000)
const baseDir = path.resolve(process.env.FILE_SERVER_BASE_DIR || process.cwd())
const token = process.env.FILE_SERVER_TOKEN || null

function ensureWithinBaseDir(resolvedPath, base) {
  const normalizedBase = path.join(base, path.sep)
  return resolvedPath.startsWith(normalizedBase)
}

const server = http.createServer(async (req, res) => {
  try {
    // Optional bearer token auth
    if (token) {
      const authHeader = req.headers['authorization'] || ''
      if (authHeader !== `Bearer ${token}`) {
        res.writeHead(401, { 'Content-Type': 'text/plain' })
        res.end('Unauthorized')
        return
      }
    }

    const url = new URL(req.url, `http://${req.headers.host}`)

    // Health check
    if (req.method === 'GET' && url.pathname === '/health') {
      res.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' })
      res.end(JSON.stringify({ status: 'ok', baseDir }))
      return
    }

    // Serve files from /files/<filename>
    if (req.method === 'GET' && url.pathname.startsWith('/files/')) {
      const requested = decodeURIComponent(url.pathname.slice('/files/'.length))
      if (!requested) {
        res.writeHead(400, { 'Content-Type': 'text/plain' })
        res.end('filename is required')
        return
      }

      // Prevent path traversal; normalize and join within baseDir
      const safeRelative = path.normalize(requested).replace(/^([.][.][\/])+/, '')
      const filePath = path.join(baseDir, safeRelative)
      const resolved = path.resolve(filePath)

      if (!ensureWithinBaseDir(resolved, baseDir)) {
        res.writeHead(403, { 'Content-Type': 'text/plain' })
        res.end('Forbidden')
        return
      }

      // Check existence and readability
      await fsp.access(resolved, fs.constants.R_OK)
      const stat = await fsp.stat(resolved)

      res.writeHead(200, {
        'Content-Type': 'application/octet-stream',
        'Content-Length': stat.size,
        'Content-Disposition': `attachment; filename="${path.basename(resolved)}"`,
        'Cache-Control': 'no-store',
      })

      const stream = fs.createReadStream(resolved)
      stream.on('error', (err) => {
        console.error('[file-server] stream error:', err)
        if (!res.headersSent) {
          res.writeHead(500, { 'Content-Type': 'text/plain' })
        }
        res.end('stream error')
      })
      stream.pipe(res)
      return
    }

    res.writeHead(404, { 'Content-Type': 'text/plain' })
    res.end('Not found')
  } catch (err) {
    const status = err && err.code === 'ENOENT' ? 404 : 500
    res.writeHead(status, { 'Content-Type': 'text/plain' })
    res.end(err && err.message ? err.message : 'Internal Server Error')
  }
})

server.listen(port, '0.0.0.0', () => {
  console.log(`[file-server] Listening on http://0.0.0.0:${port}`)
  console.log(`[file-server] Base directory: ${baseDir}`)
  console.log(`[file-server] Health: http://0.0.0.0:${port}/health`)
  console.log(`[file-server] Files:  http://0.0.0.0:${port}/files/<filename>`)
  console.log(
    '[file-server] From LocalStack/Lambda use: http://host.docker.internal:' +
      port +
      '/files/<filename>'
  )
  if (token) {
    console.log('[file-server] Auth required: set Authorization: Bearer <token>')
  }
})
