# GCB Admin Portal Dashboard

Static web assets and nginx configuration for the GCB Admin Portal at `admin.gcbehavioral.com`.

This repository contains the front-end dashboard that serves as the main entry point and navigation hub for the GCB administrative tools, including billing management and payroll systems.

## Overview

The GCB Admin Portal provides:
- **Home Page**: Navigation cards for accessing billing and payroll tools
- **Shared Components**: Global header with navigation dropdown and footer
- **Static Resources**: Favicon and images
- **Nginx Configuration**: Reverse proxy setup with authentication

## Repository Structure

```
gcb-dashboard/
├── www/                              # Static web files
│   ├── index.html                    # Home page with navigation cards
│   ├── status.html                   # Legacy status page (being migrated)
│   ├── newstatus.html                # Status page variant
│   ├── shared/                       # Shared components
│   │   ├── header.html               # Global navigation header
│   │   ├── footer.html               # Global footer
│   │   └── images/
│   │       └── favicon.ico           # Shared favicon
│   └── images/
│       └── favicon.ico               # Root favicon
├── nginx/
│   └── sites-available/
│       └── admin.gcbehavioral.com    # Nginx site configuration
├── deployment/
│   └── deploy.sh                     # Automated deployment script
├── .git/hooks/
│   └── post-commit                   # Auto-deployment git hook
├── .gitignore                        # Excludes sensitive files
└── README.md                         # This file
```

## Deployment

### Automatic Deployment (Post-Commit Hook)

After every commit, the post-commit hook automatically deploys changes:

```bash
git commit -m "Update header navigation"
# → 5 second countdown
# → Automatic deployment
# → Changes live at admin.gcbehavioral.com
```

To skip deployment for a commit:
```bash
SKIP_DEPLOY=1 git commit -m "WIP: testing changes"
```

### Manual Deployment

```bash
# Normal deployment (with confirmation)
./deployment/deploy.sh

# Automatic deployment (no prompts)
./deployment/deploy.sh --force

# Test without making changes
./deployment/deploy.sh --dry-run

# Deploy only web files (skip nginx reload)
./deployment/deploy.sh --skip-nginx
```

## Quick Start

```bash
cd ~/Dev/GCB/gcb-dashboard

# Edit files
nano www/index.html

# Commit (triggers auto-deployment)
git commit -am "Update home page"
```

For full documentation, see sections below.

---

**Last Updated**: 2026-01-12

