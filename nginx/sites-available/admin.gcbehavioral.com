# HTTP Block - Redirects all traffic to HTTPS
server {
    listen 80;
    server_name admin.gcbehavioral.com;

    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS Block
server {
    listen 443 ssl http2;
    server_name admin.gcbehavioral.com;

    # --- SSL Configuration ---
    ssl_certificate /etc/ssl/gcbehavioral.com/origin-cert.pem;
    ssl_certificate_key /etc/ssl/gcbehavioral.com/private-key.pem;

    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    # --- 1. Global Authentication (The Gatekeeper) ---
    # Every request to this server MUST pass this check first
    auth_request /auth/verify;
    
    # If auth fails (401), redirect to login
    error_page 401 = @error401;
    location @error401 {
        return 302 /auth/login;
    }

    # --- 2. Auth Service Endpoints (Public) ---
    
    # Internal Verification Endpoint (Used by Nginx)
    location = /auth/verify {
        internal;
        proxy_pass http://127.0.0.1:8001/auth/verify;
        proxy_pass_request_body off;
        proxy_set_header Content-Length "";
        proxy_set_header X-Original-URI $request_uri;
    }

    # Public Login Routes
    location /auth/ {
        auth_request off; # Disable auth check for the login page itself
        proxy_pass http://127.0.0.1:8001; 
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # --- 3. Home Page (Host Based) ---
    location = / {
        root /var/www/admin;
        try_files /index.html =404;
    }

    # --- 4. Specific Static File Exception ---
    location = /status.html {
        root /var/www/admin;
    }

    # --- 5. Static Images (Host Based) ---
    location /images/ {
        root /var/www/admin;
        expires 30d;
        access_log off;
    }

    # --- 6. Shared Resources (Host Based) ---
    location /shared/ {
        root /var/www/admin;
        expires 30d;
        access_log off;
    }

    # --- 7. The Billing App (Consolidated) ---
    location /billing/ {
        proxy_pass http://127.0.0.1:8000/billing/;

        # CRITICAL: Pass User Info Headers from Auth Service to Billing App
        auth_request_set $user_email $upstream_http_x_user_email;
        auth_request_set $user_name $upstream_http_x_user_name;
        auth_request_set $user_picture $upstream_http_x_user_picture;

        proxy_set_header X-User-Email $user_email;
        proxy_set_header X-User-Name $user_name;
        proxy_set_header X-User-Picture $user_picture;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_read_timeout 60s;
        proxy_connect_timeout 60s;
    }

    location /payroll {
    proxy_pass http://127.0.0.1:8082;

    auth_request_set $user_email $upstream_http_x_user_email;
    auth_request_set $user_name $upstream_http_x_user_name;
    auth_request_set $user_picture $upstream_http_x_user_picture;

    proxy_set_header X-User-Email $user_email;
    proxy_set_header X-User-Name $user_name;
    proxy_set_header X-User-Picture $user_picture;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    }

    # --- 8. Mission Control (Financial Pulse) ---
    location /mission-control/ {
        proxy_pass http://127.0.0.1:8092/mission-control/;

        # Pass User Info Headers from Auth Service
        auth_request_set $user_email $upstream_http_x_user_email;
        auth_request_set $user_name $upstream_http_x_user_name;
        auth_request_set $user_picture $upstream_http_x_user_picture;

        proxy_set_header X-User-Email $user_email;
        proxy_set_header X-User-Name $user_name;
        proxy_set_header X-User-Picture $user_picture;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_read_timeout 60s;
        proxy_connect_timeout 60s;
    }

}
