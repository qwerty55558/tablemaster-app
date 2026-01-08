# TableMaster 앱 통신 아키텍처 계획

## 1. 시스템 아키텍처 개요

### Hybrid 전략

데이터의 중요도에 따라 기술 스택을 분리하여 효율적으로 처리.

```
+------------------------------------------------------------------+
|                         Flutter App (테이블)                      |
+------------------------------------------------------------------+
                              ↓↑ WebSocket + STOMP
+------------------------------------------------------------------+
|                      Spring Backend                               |
|  +------------------+  +------------------+  +------------------+ |
|  | WebSocket/STOMP  |  | Message Handler  |  | Virtual Threads  | |
|  | (SimpMessaging)  |  | (비동기 처리)    |  | (I/O 효율화)     | |
|  +------------------+  +------------------+  +------------------+ |
+------------------------------------------------------------------+
        ↓↑                      ↓↑                      ↓↑
+------------------+    +------------------+    +------------------+
|    RabbitMQ      |    |      Redis       |    |   PostgreSQL     |
| (메시지 큐/브로커)|    | (캐시/금칙어)    |    | (로그/영속성)    |
+------------------+    +------------------+    +------------------+
```

### 기술 스택별 역할

| 기술 | 역할 | 데이터 종류 |
|------|------|-------------|
| **RabbitMQ** | 메인 메시징 브로커 | 채팅, 선물하기, 이미지 전송 |
| | (메시지 유실 방지) | Ack 메커니즘으로 신뢰성 보장 |
| **Redis** | 캐싱 & 세션 관리 | 테이블 상태 (성별, 지역) |
| | | 금칙어 목록 (빠른 필터링) |
| **PostgreSQL** | 영속성 데이터 | 채팅 로그, 통계, 불건전 로그 |

---

## 2. STOMP Destination 설계

### Subscribe (서버 → 클라이언트)

| Destination | 용도 | 구독자 | 브로커 |
|-------------|------|--------|--------|
| `/topic/tables` | 테이블 상태 브로드캐스트 | 모든 앱 | RabbitMQ (Redis 캐시) |
| `/topic/config` | 금칙어/설정 업데이트 | 모든 앱 | RabbitMQ |
| `/topic/notice` | 공지사항 | 모든 앱 | RabbitMQ |
| `/user/queue/chat` | 채팅 메시지 (개인) | 특정 테이블 | RabbitMQ |
| `/user/queue/gift` | 선물 알림 (개인) | 특정 테이블 | RabbitMQ |
| `/user/queue/alert` | 개인 알림 | 특정 테이블 | RabbitMQ |

### Send (클라이언트 → 서버)

| Destination | 용도 | 처리 |
|-------------|------|------|
| `/app/chat/send` | 채팅 메시지 전송 | RabbitMQ Queue → 대상 테이블 |
| `/app/chat/request` | 채팅 요청 | 상태 변경 + 알림 |
| `/app/gift/send` | 선물하기 | 트랜잭션 처리 후 푸시 |
| `/app/order` | 주문 | DB 저장 + 관리툴 알림 |
| `/app/log` | 로그 전송 | PostgreSQL (비동기) |

---

## 3. 메시지 JSON 구조

### 공통 Wrapper

```json
{
  "type": "MESSAGE_TYPE",
  "timestamp": "2026-01-08T12:00:00Z",
  "payload": { ... }
}
```

### MESSAGE_TYPE 종류

| Type | 방향 | 설명 |
|------|------|------|
| `TABLE_UPDATE` | Server → Client | 테이블 상태 변경 |
| `CONFIG_UPDATE` | Server → Client | 설정/금칙어 업데이트 |
| `CHAT_MESSAGE` | Both | 채팅 메시지 |
| `CHAT_REQUEST` | Both | 채팅 요청/응답 |
| `GIFT_RECEIVED` | Server → Client | 선물 수신 알림 |
| `GIFT_SENT` | Server → Client | 선물 전송 확인 |
| `ORDER_STATUS` | Server → Client | 주문 상태 변경 |
| `NOTICE` | Server → Client | 공지사항 |
| `LOG` | Client → Server | 앱 로그 |

### 상세 메시지 예시

#### TABLE_UPDATE
```json
{
  "type": "TABLE_UPDATE",
  "timestamp": "2026-01-08T12:00:00Z",
  "payload": {
    "tables": [
      {
        "id": "A1",
        "name": "A1",
        "status": "occupied",
        "guestCount": 4,
        "maleCount": 2,
        "femaleCount": 2,
        "location": "서울",
        "isChatting": true,
        "updatedAt": "2026-01-08T12:00:00Z"
      }
    ]
  }
}
```

#### CONFIG_UPDATE (금칙어)
```json
{
  "type": "CONFIG_UPDATE",
  "timestamp": "2026-01-08T12:00:00Z",
  "payload": {
    "configType": "FORBIDDEN_WORDS",
    "version": "1.0.2",
    "data": {
      "words": ["금칙어1", "금칙어2"],
      "action": "REPLACE"
    }
  }
}
```

#### CHAT_MESSAGE
```json
{
  "type": "CHAT_MESSAGE",
  "timestamp": "2026-01-08T12:00:00Z",
  "payload": {
    "messageId": "msg_123",
    "fromTableId": "A1",
    "toTableId": "A2",
    "content": "안녕하세요!",
    "contentType": "TEXT",
    "sentAt": "2026-01-08T12:00:00Z"
  }
}
```

#### CHAT_REQUEST
```json
{
  "type": "CHAT_REQUEST",
  "timestamp": "2026-01-08T12:00:00Z",
  "payload": {
    "requestId": "req_123",
    "fromTableId": "A1",
    "toTableId": "A2",
    "status": "PENDING",
    "message": "채팅 요청합니다"
  }
}
```

#### GIFT_RECEIVED
```json
{
  "type": "GIFT_RECEIVED",
  "timestamp": "2026-01-08T12:00:00Z",
  "payload": {
    "giftId": "gift_123",
    "fromTableId": "A1",
    "giftType": "DRINK",
    "giftName": "샴페인",
    "message": "즐거운 시간 되세요!",
    "imageUrl": "/images/gifts/champagne.png"
  }
}
```

#### LOG (앱 → 서버)
```json
{
  "type": "LOG",
  "timestamp": "2026-01-08T12:00:00Z",
  "payload": {
    "deviceId": "abc123",
    "tableId": "A1",
    "level": "INFO",
    "category": "CHAT",
    "message": "채팅 요청 전송",
    "metadata": {
      "targetTableId": "A2",
      "requestId": "req_123"
    }
  }
}
```

---

## 4. 메시지 흐름 시나리오

### 4.1 채팅 요청 흐름

```
1. [A1 앱] --SEND /app/chat/request--> [백엔드]
   { "targetTableId": "A2", "message": "채팅 요청합니다" }

2. [백엔드] 처리:
   - 금칙어 체크 (Redis)
   - 테이블 상태 확인 (Redis)
   - 요청 저장 (PostgreSQL)

3. [백엔드] --/user/queue/chat--> [A2 앱]
   { "type": "CHAT_REQUEST", "fromTableId": "A1", "status": "PENDING" }

4. [백엔드] --/user/queue/alert--> [A1 앱]
   { "type": "CHAT_REQUEST_SENT", "toTableId": "A2" }

5. [백엔드] --/topic/tables--> [관리툴 + 모든 앱]
   { "type": "TABLE_UPDATE", ... (A1, A2 상태 변경) }
```

### 4.2 선물하기 흐름

```
1. [A1 앱] --SEND /app/gift/send--> [백엔드]
   { "targetTableId": "A2", "giftType": "DRINK", "giftId": "champagne" }

2. [백엔드] 트랜잭션 처리:
   - 잔액 확인 & 차감
   - 선물 내역 저장 (PostgreSQL)
   - 커밋 완료 후 메시지 전송

3. [백엔드] --/user/queue/gift--> [A2 앱]
   { "type": "GIFT_RECEIVED", "fromTableId": "A1", "giftName": "샴페인" }

4. [백엔드] --/user/queue/alert--> [A1 앱]
   { "type": "GIFT_SENT", "toTableId": "A2", "giftName": "샴페인" }

5. [백엔드] --/topic/logs--> [관리툴]
   { 선물 내역 로그 }
```

### 4.3 금칙어 업데이트 흐름

```
1. [관리툴] HTTP POST /api/v1/config/forbidden-words
   { "words": ["금칙어1", "금칙어2"], "action": "REPLACE" }

2. [백엔드] 처리:
   - Redis 업데이트
   - 버전 증가

3. [백엔드] --/topic/config--> [모든 앱]
   { "type": "CONFIG_UPDATE", "configType": "FORBIDDEN_WORDS", ... }

4. [각 앱] 로컬 캐시 업데이트
```

### 4.4 테이블 상태 브로드캐스트

```
1. [백엔드] Redis에서 테이블 상태 변경 감지 (또는 주기적 폴링)

2. [백엔드] --/topic/tables--> [모든 클라이언트]
   { "type": "TABLE_UPDATE", "payload": { "tables": [...] } }

3. [각 앱/관리툴] UI 업데이트
```

---

## 5. Flutter 앱 구현 계획

### 5.1 파일 구조

```
lib/
├── services/
│   ├── stomp_service.dart        # STOMP 연결 관리
│   ├── message_handler.dart      # 수신 메시지 분기 처리
│   ├── log_service.dart          # 로그 전송 (오프라인 큐 포함)
│   └── api_service.dart          # REST API (기존)
├── models/
│   ├── stomp_message.dart        # STOMP 메시지 모델
│   ├── config_model.dart         # 설정 모델 (금칙어 등)
│   ├── chat_message.dart         # 채팅 메시지 모델
│   ├── gift_model.dart           # 선물 모델
│   └── table_model.dart          # 테이블 모델 (기존)
├── cache/
│   └── config_cache.dart         # 금칙어 등 로컬 캐시
└── config/
    └── api_config.dart           # API/WS 설정 (기존)
```

### 5.2 stomp_service.dart 주요 기능

```dart
class StompService {
  // 연결 관리
  Future<void> connect();
  void disconnect();
  void reconnect();
  
  // 구독
  void subscribeToTables();           // /topic/tables
  void subscribeToConfig();           // /topic/config
  void subscribeToPersonalQueue();    // /user/queue/*
  
  // 전송
  void sendChatRequest(String targetTableId, String message);
  void sendChatMessage(String targetTableId, String content);
  void sendGift(String targetTableId, String giftId);
  void sendLog(LogMessage log);
  
  // 상태
  bool get isConnected;
  Stream<StompConnectionState> get connectionState;
}
```

### 5.3 message_handler.dart 주요 기능

```dart
class MessageHandler {
  void handleMessage(StompFrame frame) {
    final message = StompMessage.fromJson(frame.body);
    
    switch (message.type) {
      case 'TABLE_UPDATE':
        _handleTableUpdate(message.payload);
        break;
      case 'CONFIG_UPDATE':
        _handleConfigUpdate(message.payload);
        break;
      case 'CHAT_MESSAGE':
        _handleChatMessage(message.payload);
        break;
      case 'CHAT_REQUEST':
        _handleChatRequest(message.payload);
        break;
      case 'GIFT_RECEIVED':
        _handleGiftReceived(message.payload);
        break;
      // ...
    }
  }
}
```

### 5.4 의존성 패키지

```yaml
dependencies:
  stomp_dart_client: ^1.0.0    # STOMP 클라이언트
  # web_socket_channel 제거 (stomp_dart_client 내장)
```

---

## 6. 오프라인 처리 전략

### 6.1 앱 로컬 처리

| 데이터 | 오프라인 시 처리 | 재연결 시 처리 |
|--------|------------------|----------------|
| **설정/금칙어** | 로컬 캐시 사용 | 버전 비교 후 업데이트 |
| **로그** | 로컬 큐에 저장 | 배치로 서버 전송 |
| **채팅 메시지** | 전송 대기 표시 | 순서대로 재전송 |
| **테이블 상태** | 마지막 상태 표시 | 즉시 업데이트 |

### 6.2 백엔드 처리 (RabbitMQ)

- 앱이 오프라인일 때 개인 메시지는 RabbitMQ Queue에 보관
- 재연결 시 미수신 메시지 순차 전달
- TTL 설정으로 오래된 메시지 자동 삭제

---

## 7. 보안 고려사항

### 7.1 인증

- STOMP CONNECT 시 헤더에 JWT 토큰 전달
- 백엔드에서 토큰 검증 후 연결 허용
- 토큰 만료 시 재인증 후 재연결

```dart
stompClient.connect(
  headers: {
    'Authorization': 'Bearer $token',
    'deviceId': deviceId,
  },
);
```

### 7.2 금칙어 필터링

- 채팅 메시지 전송 전 클라이언트 1차 필터링 (UX)
- 백엔드 2차 필터링 (보안, 최신 금칙어)
- 위반 시 메시지 차단 + 로그 저장

### 7.3 데이터 검증

- 모든 수신 메시지 JSON 스키마 검증
- 비정상 메시지 무시 + 로그 기록

---

## 8. 구현 우선순위

### Phase 1: 기본 연결 (MVP)
1. `stomp_dart_client` 패키지 추가
2. `StompService` 기본 구현 (connect, disconnect)
3. `/topic/tables` 구독 → 테이블 상태 실시간 업데이트
4. 기존 `WebSocketService` 제거

### Phase 2: 채팅 기능
1. `/app/chat/request` 전송
2. `/user/queue/chat` 구독
3. 채팅 UI 구현

### Phase 3: 설정 동기화
1. `/topic/config` 구독
2. 금칙어 로컬 캐시 구현
3. 채팅 메시지 필터링 적용

### Phase 4: 선물/주문
1. `/app/gift/send` 전송
2. `/user/queue/gift` 구독
3. 선물 UI 구현

### Phase 5: 로그 & 오프라인
1. `LogService` 구현
2. 오프라인 큐 구현
3. 재연결 로직 강화

---

## 9. 확인 필요 사항 (백엔드)

| 항목 | 질문 | 기본값 (앱) |
|------|------|-------------|
| WebSocket URL | `ws://host:port/ws`? | `ws://localhost:3000/ws` |
| STOMP Heartbeat | 간격? | 10초 |
| 인증 헤더 | `Authorization: Bearer`? | Yes |
| 금칙어 초기 로드 | REST? STOMP? | REST `/api/v1/config/forbidden-words` |
| 메시지 TTL | 오프라인 보관 기간? | 24시간 |
| 재연결 정책 | 최대 재시도 횟수? | 5회 (exponential backoff) |

---

## 10. 참고 자료

- [Spring WebSocket + STOMP 공식 문서](https://docs.spring.io/spring-framework/docs/current/reference/html/web.html#websocket-stomp)
- [RabbitMQ STOMP Plugin](https://www.rabbitmq.com/stomp.html)
- [stomp_dart_client 패키지](https://pub.dev/packages/stomp_dart_client)
