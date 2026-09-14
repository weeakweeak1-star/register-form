# deploy.ps1
Write-Host "Building Form App..."
flutter build web -t lib/main_form.dart --base-href "/register-form/"
Remove-Item -Recurse -Force build/web_form -ErrorAction Ignore
Rename-Item -Path build/web -NewName web_form
(Get-Content build/web_form/manifest.json) -replace '"name": "ادارة وياك"', '"name": "استمارة التسجيل"' | Set-Content build/web_form/manifest.json
(Get-Content build/web_form/manifest.json) -replace '"short_name": "ادارة وياك"', '"short_name": "استمارة التسجيل"' | Set-Content build/web_form/manifest.json
(Get-Content build/web_form/manifest.json) -replace '"start_url": "."', '"start_url": "/register-form/"' | Set-Content build/web_form/manifest.json
(Get-Content build/web_form/index.html) -replace '<title>ادارة وياك</title>', '<title>استمارة التسجيل</title>' | Set-Content build/web_form/index.html

Write-Host "Building Admin App..."
flutter build web -t lib/main.dart --base-href "/register-form/admin/"
Remove-Item -Recurse -Force build/web_admin -ErrorAction Ignore
Rename-Item -Path build/web -NewName web_admin
(Get-Content build/web_admin/manifest.json) -replace '"start_url": "."', '"start_url": "/register-form/admin/"' | Set-Content build/web_admin/manifest.json

Write-Host "Preparing Final Folder..."
Remove-Item -Force build/web_form/flutter_service_worker.js -ErrorAction Ignore
Remove-Item -Force build/web_admin/flutter_service_worker.js -ErrorAction Ignore

Remove-Item -Recurse -Force build/final_publish -ErrorAction Ignore
New-Item -ItemType Directory -Force -Path build/final_publish
Copy-Item -Path build/web_form/* -Destination build/final_publish -Recurse
New-Item -ItemType Directory -Force -Path build/final_publish/admin
Copy-Item -Path build/web_admin/* -Destination build/final_publish/admin -Recurse

Write-Host "Pushing to gh-pages branch..."
Set-Location build/final_publish
git init
git checkout -b gh-pages
git add .
git commit -m "Manual deploy from local machine"
git push -f https://github.com/weeakweeak1-star/register-form.git gh-pages
Write-Host "Deployed successfully!"
