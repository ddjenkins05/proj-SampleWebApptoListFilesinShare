# Sample PoC Web App (Node.js)

This sample exposes:

- `GET /` browser UI for upload and file list
- `POST /upload` to upload one file using `multipart/form-data` field `file`
- `GET /files` to list files currently in `D:\\home\\hangfire`

It uses regular filesystem I/O only (no Azure Storage SDK).

## Local run

```powershell
npm install
npm start
```

## Deploy to your App Service

From `sample-app` directory:

```powershell
az webapp deploy --resource-group <your-rg> --name <web-app-name> --src-path .
```

## Test endpoints

Open the UI in browser:

```powershell
start "https://<web-app-name>.azurewebsites.net/"
```

Or test API endpoints directly:

Upload:

```powershell
curl -X POST "https://<web-app-name>.azurewebsites.net/upload" -F "file=@C:/temp/test.txt"
```

List files:

```powershell
curl "https://<web-app-name>.azurewebsites.net/files"
```
