# Sample PoC Web App (Node.js)

This sample exposes:

- `GET /` browser UI for upload and file list
- `POST /upload` to upload one file using `multipart/form-data` field `file`
- `GET /files` to list files currently in `D:\\home\\hangfire`
 - `GET /files` to list files currently in `/home/hangfire` (Azure File share mount)

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

This repository also contains a Bicep template at the repo root (`main.bicep`) which can create the Storage Account, File Share, App Service Plan and Web App and configure the Azure File share mount. To deploy the full infrastructure and the app together, run from the `sample-app` folder:

```powershell
az deployment group create --resource-group <your-rg> --template-file ..\main.bicep --parameters webAppName=<web-app-name>
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
