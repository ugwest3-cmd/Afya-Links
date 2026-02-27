@echo off
cd /d "C:\Users\Fix\Desktop\Afya Links"
git add backend/src/controllers/admin.controller.ts backend/src/routes/admin.routes.ts admin-dashboard/src/pages/Users.tsx admin-dashboard/src/components/Layout.tsx admin-dashboard/src/App.tsx
git commit -m "Feat: Add Users Management page to Admin Dashboard and necessary backend endpoints"
git push origin main
echo Done! Admin dashboard features pushed to GitHub.
pause
