#!/bin/bash
#
# GCB Dashboard Deployment Script
#
# This script deploys the GCB Admin Portal static files and nginx configuration
# from the git repository to production locations.
#
# Usage: ./deployment/deploy.sh [--dry-run] [--force] [--skip-nginx]
#
# Options:
#   --dry-run     Show what would be deployed without making changes
#   --force       Skip confirmation prompts
#   --skip-nginx  Skip nginx configuration deployment and reload
#

set -e  # Exit on any error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Determine script directory (works even if called from elsewhere)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Deployment targets
WWW_TARGET="/var/www/billing"
NGINX_TARGET="/etc/nginx/sites-available"
NGINX_SITE="admin.gcbehavioral.com"

# Parse command line options
DRY_RUN=false
FORCE=false
SKIP_NGINX=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --skip-nginx)
            SKIP_NGINX=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--dry-run] [--force] [--skip-nginx]"
            echo ""
            echo "Options:"
            echo "  --dry-run     Show what would be deployed without making changes"
            echo "  --force       Skip confirmation prompts"
            echo "  --skip-nginx  Skip nginx configuration deployment and reload"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Print functions
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Validation functions
validate_repo_structure() {
    print_info "Validating repository structure..."

    local required_files=(
        "$REPO_DIR/www/index.html"
        "$REPO_DIR/www/shared/header.html"
        "$REPO_DIR/www/shared/footer.html"
        "$REPO_DIR/nginx/sites-available/$NGINX_SITE"
    )

    local missing_files=()

    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done

    if [[ ${#missing_files[@]} -gt 0 ]]; then
        print_error "Missing required files:"
        for file in "${missing_files[@]}"; do
            echo "    - $file"
        done
        return 1
    fi

    print_success "Repository structure valid"
    return 0
}

validate_html_files() {
    print_info "Validating HTML files..."

    local html_files=(
        "$REPO_DIR/www/index.html"
        "$REPO_DIR/www/status.html"
        "$REPO_DIR/www/newstatus.html"
        "$REPO_DIR/www/shared/header.html"
        "$REPO_DIR/www/shared/footer.html"
    )

    local invalid_files=()

    for file in "${html_files[@]}"; do
        if [[ -f "$file" ]]; then
            # Basic HTML validation - check for opening and closing tags
            if ! grep -q "<html" "$file" 2>/dev/null && ! grep -q "<!-- GLOBAL" "$file" 2>/dev/null; then
                invalid_files+=("$file")
            fi
        fi
    done

    if [[ ${#invalid_files[@]} -gt 0 ]]; then
        print_warning "Some HTML files may be invalid (missing HTML tags):"
        for file in "${invalid_files[@]}"; do
            echo "    - $file"
        done
        print_info "Continuing anyway (partials may not have <html> tags)"
    else
        print_success "HTML files appear valid"
    fi

    return 0
}

validate_nginx_config() {
    print_info "Validating nginx configuration syntax..."

    local temp_nginx="/tmp/nginx-test-$$"

    # Copy current nginx config to temp location
    cp "$NGINX_TARGET/$NGINX_SITE" "$temp_nginx" 2>/dev/null || true

    # Copy new config to temp location
    cp "$REPO_DIR/nginx/sites-available/$NGINX_SITE" "$temp_nginx"

    # Test nginx config
    if sudo nginx -t -c "$temp_nginx" 2>&1 | grep -q "syntax is ok"; then
        print_success "Nginx configuration syntax valid"
        rm -f "$temp_nginx"
        return 0
    else
        print_error "Nginx configuration has syntax errors"
        rm -f "$temp_nginx"
        return 1
    fi
}

check_sudo_access() {
    print_info "Checking sudo access..."

    if ! sudo -n true 2>/dev/null; then
        print_warning "Sudo password required for deployment"
        sudo -v
    fi

    print_success "Sudo access confirmed"
}

show_deployment_plan() {
    print_header "DEPLOYMENT PLAN"

    echo "Repository: $REPO_DIR"
    echo "Target:     $WWW_TARGET"
    echo ""
    echo "Files to deploy:"
    echo "  • index.html"
    echo "  • status.html"
    echo "  • newstatus.html"
    echo "  • shared/header.html"
    echo "  • shared/footer.html"
    echo "  • shared/images/favicon.ico"
    echo "  • images/favicon.ico"

    if [[ "$SKIP_NGINX" == false ]]; then
        echo ""
        echo "Nginx configuration:"
        echo "  • $NGINX_SITE"
    fi

    echo ""
}

confirm_deployment() {
    if [[ "$FORCE" == true ]]; then
        return 0
    fi

    echo -n "Proceed with deployment? (y/N): "
    read -r response

    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_warning "Deployment cancelled by user"
        exit 0
    fi
}

deploy_web_files() {
    print_header "DEPLOYING WEB FILES"

    local files=(
        "index.html"
        "status.html"
        "newstatus.html"
    )

    local shared_files=(
        "shared/header.html"
        "shared/footer.html"
        "shared/images/favicon.ico"
    )

    local image_files=(
        "images/favicon.ico"
    )

    # Deploy root HTML files
    for file in "${files[@]}"; do
        print_info "Deploying $file..."
        if [[ "$DRY_RUN" == true ]]; then
            echo "    [DRY-RUN] Would copy: $REPO_DIR/www/$file → $WWW_TARGET/$file"
        else
            sudo cp "$REPO_DIR/www/$file" "$WWW_TARGET/$file"
            print_success "$file deployed"
        fi
    done

    # Deploy shared files
    for file in "${shared_files[@]}"; do
        print_info "Deploying $file..."
        if [[ "$DRY_RUN" == true ]]; then
            echo "    [DRY-RUN] Would copy: $REPO_DIR/www/$file → $WWW_TARGET/$file"
        else
            sudo cp "$REPO_DIR/www/$file" "$WWW_TARGET/$file"
            print_success "$file deployed"
        fi
    done

    # Deploy image files
    for file in "${image_files[@]}"; do
        print_info "Deploying $file..."
        if [[ "$DRY_RUN" == true ]]; then
            echo "    [DRY-RUN] Would copy: $REPO_DIR/www/$file → $WWW_TARGET/$file"
        else
            sudo cp "$REPO_DIR/www/$file" "$WWW_TARGET/$file"
            print_success "$file deployed"
        fi
    done

    # Fix ownership and permissions
    if [[ "$DRY_RUN" == false ]]; then
        print_info "Setting ownership and permissions..."
        sudo chown -R root:puki "$WWW_TARGET"
        sudo chmod 755 "$WWW_TARGET"
        sudo find "$WWW_TARGET" -type f -exec chmod 664 {} \;
        sudo find "$WWW_TARGET" -type d -exec chmod 755 {} \;
        print_success "Ownership and permissions set"
    fi
}

deploy_nginx_config() {
    if [[ "$SKIP_NGINX" == true ]]; then
        print_warning "Skipping nginx configuration deployment"
        return 0
    fi

    print_header "DEPLOYING NGINX CONFIGURATION"

    print_info "Deploying $NGINX_SITE..."
    if [[ "$DRY_RUN" == true ]]; then
        echo "    [DRY-RUN] Would copy: $REPO_DIR/nginx/sites-available/$NGINX_SITE → $NGINX_TARGET/$NGINX_SITE"
    else
        sudo cp "$REPO_DIR/nginx/sites-available/$NGINX_SITE" "$NGINX_TARGET/$NGINX_SITE"
        sudo chown root:puki "$NGINX_TARGET/$NGINX_SITE"
        sudo chmod 664 "$NGINX_TARGET/$NGINX_SITE"
        print_success "Nginx configuration deployed"
    fi
}

test_and_reload_nginx() {
    if [[ "$SKIP_NGINX" == true ]]; then
        return 0
    fi

    print_header "TESTING & RELOADING NGINX"

    print_info "Testing nginx configuration..."
    if [[ "$DRY_RUN" == true ]]; then
        echo "    [DRY-RUN] Would run: sudo nginx -t"
        echo "    [DRY-RUN] Would run: sudo systemctl reload nginx"
    else
        if sudo nginx -t; then
            print_success "Nginx configuration test passed"

            print_info "Reloading nginx..."
            if sudo systemctl reload nginx; then
                print_success "Nginx reloaded successfully"
            else
                print_error "Failed to reload nginx"
                return 1
            fi
        else
            print_error "Nginx configuration test failed"
            print_error "Nginx was NOT reloaded - old configuration still active"
            return 1
        fi
    fi
}

show_deployment_summary() {
    print_header "DEPLOYMENT SUMMARY"

    if [[ "$DRY_RUN" == true ]]; then
        print_info "DRY RUN completed - no changes were made"
    else
        print_success "Deployment completed successfully!"

        echo ""
        echo "Deployed to:"
        echo "  • Web files: $WWW_TARGET"
        if [[ "$SKIP_NGINX" == false ]]; then
            echo "  • Nginx config: $NGINX_TARGET/$NGINX_SITE"
        fi

        echo ""
        print_info "You can verify the deployment at: https://admin.gcbehavioral.com"
    fi
}

rollback_deployment() {
    print_error "Deployment failed!"
    print_warning "You may need to manually restore from backups"
    exit 1
}

# Main deployment process
main() {
    print_header "GCB DASHBOARD DEPLOYMENT"

    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN MODE - No changes will be made"
    fi

    # Pre-deployment checks
    validate_repo_structure || exit 1
    validate_html_files || exit 1

    if [[ "$DRY_RUN" == false ]]; then
        check_sudo_access || exit 1
    fi

    # Show plan and confirm
    show_deployment_plan
    confirm_deployment

    # Execute deployment
    deploy_web_files || rollback_deployment
    deploy_nginx_config || rollback_deployment
    test_and_reload_nginx || rollback_deployment

    # Success!
    show_deployment_summary
}

# Run main function
main "$@"
