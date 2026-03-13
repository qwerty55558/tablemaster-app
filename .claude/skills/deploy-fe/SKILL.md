---
name: deploy-fe
description: Flutter web 빌드 → colima 메모리 부스트 → buildx amd64 이미지 → ghcr.io 푸시 → colima 원복 (멀티태스크 대응)
user_invocable: true
---

# Frontend Docker Build & Push (Flutter Web)

Flutter web을 프로덕션 빌드한 뒤, colima에 메모리를 몰아서 buildx로 amd64 이미지를 빌드하고 ghcr.io에 푸시한다.
멀티태스크 환경을 고려하여, colima가 이미 부스트 상태면 재시작하지 않고 그대로 사용한다.

## Steps

### 1. GitHub 사용자 확인 & ghcr.io 로그인
- `gh auth status`에서 **Active account**의 username을 가져온다. 하드코딩 금지.
```bash
GH_USER=$(gh api user --jq '.login')
echo $(gh auth token) | docker login ghcr.io -u "$GH_USER" --password-stdin
```

### 2. colima 메모리 부스트 (조건부)
- `colima list`로 현재 메모리 확인
- **이미 16GB 이상이면 재시작 스킵** (다른 빌드 태스크가 사용 중일 수 있음)
- 2GB(기본)이면 stop → `colima start --cpu 4 --memory 16`

### 3. 이미지 태그 결정
- `git remote get-url origin`에서 `owner/repo` 추출 → `ghcr.io/<owner>/<repo>:latest`
```bash
REPO_SLUG=$(git remote get-url origin | sed 's/.*github\.com[:/]\(.*\)\.git/\1/' | tr '[:upper:]' '[:lower:]')
IMAGE="ghcr.io/${REPO_SLUG}:latest"
```

### 4. Flutter web 프로덕션 빌드 & Docker 이미지 빌드/푸시
이 프로젝트는 Flutter web + flutter_dotenv 구조이다.
- `main.dart`에서 `IS_PROD` dart-define으로 `.env.production` 파일을 선택한다.
- `.env.production` 파일은 dotenv가 런타임에 assets에서 읽으므로, 빌드 결과물에 포함되어야 한다.

#### 4-1. Flutter web 빌드
```bash
flutter build web --release --dart-define=IS_PROD=true
```
- `--dart-define=IS_PROD=true` → `main.dart`에서 `.env.production`을 로드하게 된다.
- 빌드 결과물: `build/web/`

#### 4-2. .env.production이 build/web/assets에 포함됐는지 확인
flutter_dotenv는 pubspec.yaml의 assets에 `.env.production`이 등록되어 있어야 빌드 시 자동 포함된다.
빌드 후 `build/web/assets/.env.production` 존재 여부를 확인하고, 없으면 에러로 중단한다.

#### 4-3. Docker buildx 빌드 & 푸시
Dockerfile은 `build/web`을 nginx에 복사하는 구조이므로, Flutter 빌드가 완료된 후 실행한다.
```bash
BUILDER_NAME="fe-builder-$(head -c 4 /dev/urandom | xxd -p)"
docker buildx create --name "$BUILDER_NAME" --use
docker buildx build --platform linux/amd64 \
  -t "$IMAGE" \
  --push .
docker buildx rm "$BUILDER_NAME"
```
- 빌더 이름에 랜덤 suffix를 붙여 멀티태스크 시 충돌을 방지한다.
- 빌드 완료 후 자기 빌더는 즉시 정리한다.
- Dockerfile에 build-arg는 없다. Flutter 빌드 결과물(`build/web/`)을 그대로 nginx에 복사한다.

## Notes
- Flutter web 빌드가 반드시 Docker 빌드 전에 완료되어야 한다 (Dockerfile이 `build/web`을 COPY함).
- `--dart-define=IS_PROD=true`가 핵심 — 이것 없으면 `.env.web`을 로드하게 됨.
- colima 부스트 메모리는 16GB 고정.
- 후처리(builder 정리, colima 원복)는 사용자가 직접 관리한다. 스킬에서 자동으로 수행하지 않는다.
