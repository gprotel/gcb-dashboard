# Testing the Deployment System

This guide walks you through testing the deployment script and post-commit hook.

## 1. Test Deployment Script (Dry Run)

Test the deployment without making any changes:

```bash
cd ~/Dev/GCB/gcb-dashboard
./deployment/deploy.sh --dry-run
```

**Expected output:**
- ✓ Repository structure validation passes
- ✓ HTML files validation passes
- Shows deployment plan (files to copy)
- Shows "[DRY-RUN] Would copy..." messages
- No actual files copied
- No nginx reload

## 2. Test Deployment Script (Real Run - Careful!)

Run actual deployment to verify everything works:

```bash
cd ~/Dev/GCB/gcb-dashboard
./deployment/deploy.sh
```

**Expected output:**
- ✓ Validates files
- ✓ Checks sudo access (may prompt for password)
- Shows deployment plan
- Prompts: "Proceed with deployment? (y/N):"
- Type `y` and press Enter
- Copies files to /var/www/admin/
- Copies nginx config to /etc/nginx/sites-available/
- Sets ownership to root:puki
- Tests nginx configuration
- Reloads nginx
- ✓ Deployment completed successfully!

**Verify deployment:**
```bash
# Check files were copied
ls -la /var/www/admin/

# Check nginx config
sudo nginx -t

# Visit website
curl -I https://admin.gcbehavioral.com/
```

## 3. Test Post-Commit Hook (Safe Test)

Make a harmless change and commit to test auto-deployment:

```bash
cd ~/Dev/GCB/gcb-dashboard

# Make a small change to README
echo "" >> README.md
echo "<!-- Test commit: $(date) -->" >> README.md

# Commit (this will trigger the hook)
git commit -am "Test: verify post-commit hook works"
```

**Expected behavior:**
1. Commit succeeds
2. Post-commit hook runs automatically
3. Shows commit information
4. Shows "Automatic deployment will start in 5 seconds..."
5. You can press Enter to deploy immediately, or wait
6. Deployment script runs with --force flag
7. Changes deployed to production
8. Shows success message

**To cancel during countdown:**
- Press `Ctrl+C` within 5 seconds

## 4. Test Skipping Deployment

Test the SKIP_DEPLOY environment variable:

```bash
cd ~/Dev/GCB/gcb-dashboard

# Make another test change
echo "<!-- Another test: $(date) -->" >> README.md

# Commit with SKIP_DEPLOY
SKIP_DEPLOY=1 git commit -am "Test: skip deployment"
```

**Expected behavior:**
- Commit succeeds
- Post-commit hook runs
- Shows: "SKIP_DEPLOY is set - skipping automatic deployment"
- No deployment happens
- Shows: "To deploy manually, run: ./deployment/deploy.sh"

## 5. Test Selective Deployment

Test that only changed files trigger deployment:

### Test A: Only Web Files Changed

```bash
cd ~/Dev/GCB/gcb-dashboard

# Change only web file
echo "<!-- Test -->" >> www/index.html

# Commit
git commit -am "Test: only web files"
```

**Expected:**
- Deploys with `--skip-nginx` flag
- Skips nginx reload
- Message: "Only web files changed, skipping nginx reload"

### Test B: Only Nginx Config Changed

```bash
cd ~/Dev/GCB/gcb-dashboard

# Change nginx config (add comment)
echo "# Test comment" >> nginx/sites-available/admin.gcbehavioral.com

# Commit
git commit -am "Test: only nginx config"
```

**Expected:**
- Deploys nginx config
- Tests nginx configuration
- Reloads nginx

### Test C: Only Non-Deployable Files Changed

```bash
cd ~/Dev/GCB/gcb-dashboard

# Change only README
echo "Test" >> README.md

# Commit
git commit -am "Test: only documentation"
```

**Expected:**
- Shows: "No deployable files changed"
- Shows: "Skipping deployment"
- No actual deployment runs

## 6. Test Deployment Script Options

### Test --force (No Confirmation)

```bash
./deployment/deploy.sh --force
```

**Expected:**
- No "Proceed with deployment?" prompt
- Deploys immediately

### Test --skip-nginx

```bash
./deployment/deploy.sh --skip-nginx
```

**Expected:**
- Deploys web files only
- Skips nginx config copy
- Skips nginx test and reload

### Test --help

```bash
./deployment/deploy.sh --help
```

**Expected:**
- Shows usage information
- Lists all options

## 7. Test Error Handling

### Test Invalid HTML (Should Warn but Continue)

```bash
cd ~/Dev/GCB/gcb-dashboard

# Create invalid HTML
echo "not html" > www/test.html

# Try to deploy
./deployment/deploy.sh --dry-run
```

**Expected:**
- Warning about invalid HTML
- But deployment continues (since it's just a warning)

### Test Broken Nginx Config (Should Fail)

```bash
cd ~/Dev/GCB/gcb-dashboard

# Backup current config
cp nginx/sites-available/admin.gcbehavioral.com nginx/sites-available/admin.gcbehavioral.com.backup

# Break nginx config
echo "invalid syntax here" >> nginx/sites-available/admin.gcbehavioral.com

# Try to deploy (should fail)
./deployment/deploy.sh --dry-run

# Restore config
mv nginx/sites-available/admin.gcbehavioral.com.backup nginx/sites-available/admin.gcbehavioral.com
```

**Expected:**
- ✗ Nginx configuration has syntax errors
- Deployment should fail
- No changes made to production

## 8. Clean Up Test Commits

After testing, you can clean up test commits:

```bash
cd ~/Dev/GCB/gcb-dashboard

# View commit history
git log --oneline

# Reset to initial commit (CAREFUL!)
git reset --hard HEAD~5  # Adjust number based on test commits

# Or keep commits but deploy current state
./deployment/deploy.sh --force
```

## Verification Checklist

After testing, verify:

- [ ] Deployment script works with --dry-run
- [ ] Deployment script works with actual deployment
- [ ] Post-commit hook triggers automatically
- [ ] Auto-deployment countdown works (5 seconds)
- [ ] SKIP_DEPLOY environment variable works
- [ ] Selective deployment works (web only, nginx only)
- [ ] Non-deployable files don't trigger deployment
- [ ] Files copied to /var/www/admin/ correctly
- [ ] Ownership set to root:puki
- [ ] Permissions correct (755 dirs, 664 files)
- [ ] Nginx config copied correctly
- [ ] Nginx tests and reloads successfully
- [ ] Website accessible at https://admin.gcbehavioral.com
- [ ] Changes visible in browser

## Troubleshooting Tests

If tests fail:

**Check hook is executable:**
```bash
ls -la .git/hooks/post-commit
chmod +x .git/hooks/post-commit  # If needed
```

**Check deployment script is executable:**
```bash
ls -la deployment/deploy.sh
chmod +x deployment/deploy.sh  # If needed
```

**Test hook manually:**
```bash
.git/hooks/post-commit
```

**Test deployment script manually:**
```bash
./deployment/deploy.sh --dry-run
```

**Check git status:**
```bash
git status
git log --oneline
```

**Check production files:**
```bash
ls -la /var/www/admin/
sudo nginx -t
sudo systemctl status nginx
```

## Success Criteria

✅ All tests pass
✅ Deployment script runs without errors
✅ Post-commit hook triggers automatically
✅ Files deployed to correct locations
✅ Nginx reloads successfully
✅ Website accessible and shows changes
✅ Can skip deployment when needed
✅ Can run manual deployment when needed

---

**Testing Complete!** Your deployment system is ready to use.
