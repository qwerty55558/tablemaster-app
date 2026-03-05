# 로컬에서 빌드한 web 결과물을 nginx에 배포
FROM --platform=linux/amd64 nginx:alpine

COPY build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
