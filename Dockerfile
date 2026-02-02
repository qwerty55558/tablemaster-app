# syntax=docker/dockerfile:1
FROM --platform=linux/amd64 ghcr.io/cirruslabs/flutter:3.32.2 AS builder

WORKDIR /app

# pubspec 먼저 복사하여 캐시 활용
COPY pubspec.yaml pubspec.lock ./

# 의존성 설치
RUN flutter pub get

# 소스 코드 복사
COPY . .

# 프로덕션 환경 빌드
RUN flutter build web --release --dart-define-from-file=.env.production

# 프로덕션 이미지
FROM --platform=linux/amd64 nginx:alpine

# nginx 설정
COPY --from=builder /app/build/web /usr/share/nginx/html

# SPA를 위한 nginx 설정
RUN echo 'server { \
    listen 80; \
    server_name localhost; \
    root /usr/share/nginx/html; \
    index index.html; \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
    gzip on; \
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml text/javascript; \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
