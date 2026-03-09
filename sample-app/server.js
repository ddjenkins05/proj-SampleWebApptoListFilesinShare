const express = require('express');
const fs = require('fs');
const path = require('path');
const multer = require('multer');

const app = express();
const port = process.env.PORT || 3000;
const rawMountPath = process.env.STORAGE_MOUNT_PATH || '/home/hangfire';
let mountPath = rawMountPath;
// Normalize mount path for App Service Windows runtime:
// - POSIX '/home/..' -> 'D:/home/..'
// - UNC or backslash paths like '\\mounts\\share' -> 'D:\\mounts\\share'
if (process.platform === 'win32') {
  if (mountPath.startsWith('/')) {
    mountPath = 'D:' + mountPath; // '/home/hangfire' -> 'D:/home/hangfire'
  } else if (/^\\+/.test(mountPath)) {
    // Replace multiple leading backslashes with a single pair, then prefix with D:
    const backslashPath = mountPath.replace(/^\\+/, '\\\\');
    mountPath = 'D:' + backslashPath; // '\\mounts\\hangfire' -> 'D:\\mounts\\hangfire'
  }
}
mountPath = path.normalize(mountPath);
const publicPath = path.join(__dirname, 'public');

async function ensureMountPath() {
  await fs.promises.mkdir(mountPath, { recursive: true });
}

function sanitizeFileName(name) {
  return path.basename(name).replace(/[^a-zA-Z0-9._-]/g, '_');
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, mountPath),
  filename: (req, file, cb) => cb(null, `${Date.now()}-${sanitizeFileName(file.originalname)}`)
});

const upload = multer({ storage });

app.use(express.static(publicPath));

app.get('/', async (req, res) => {
  await ensureMountPath();
  res.sendFile(path.join(publicPath, 'index.html'));
});

app.get('/files', async (req, res) => {
  try {
    await ensureMountPath();
    const entries = await fs.promises.readdir(mountPath, { withFileTypes: true });

    const files = await Promise.all(
      entries
        .filter((entry) => entry.isFile())
        .map(async (entry) => {
          const fullPath = path.join(mountPath, entry.name);
          const stats = await fs.promises.stat(fullPath);
          return {
            name: entry.name,
            sizeBytes: stats.size,
            lastModifiedUtc: stats.mtime.toISOString()
          };
        })
    );

    res.json({
      mountPath,
      count: files.length,
      files
    });
  } catch (err) {
    res.status(500).json({
      error: 'Failed to list files.',
      detail: err.message
    });
  }
});

app.post('/upload', upload.single('file'), async (req, res) => {
  try {
    await ensureMountPath();

    if (!req.file) {
      return res.status(400).json({
        error: 'No file uploaded. Use multipart/form-data with field name "file".'
      });
    }

    return res.status(201).json({
      message: 'File uploaded successfully.',
      file: {
        originalName: req.file.originalname,
        storedName: req.file.filename,
        sizeBytes: req.file.size,
        fullPath: req.file.path
      }
    });
  } catch (err) {
    return res.status(500).json({
      error: 'Failed to upload file.',
      detail: err.message
    });
  }
});

app.listen(port, async () => {
  await ensureMountPath();
  console.log(`App listening on port ${port}`);
  console.log(`Using mount path: ${mountPath}`);
});
