# 구조 그림 (C4 1·2단계)

시스템이 무엇과 이어지는지만 그린다. 왜 이렇게 정했는지는 [`decisions.md`](decisions.md)와 각 ADR에 있다. 그림과 ADR이 다르면 ADR이 맞고, 이 그림을 고친다.

컴포넌트(3단계)와 코드(4단계)는 그리지 않는다. 앱 안 모듈은 [README](../README.md)의 폴더 설명과 ADR 0002 §1의 경계가 원본이다.

## 1. 시스템 컨텍스트

```mermaid
flowchart TB
  learner(["학습자"])
  operator(["운영자 (매너핏 팀)"])

  system["매너핏<br/>매너를 문제로 연습하는 앱과 그 서버"]

  google["Google 로그인"]
  firebase["Firebase<br/>Crashlytics, Analytics"]
  claude["Claude API"]
  github["GitHub<br/>Actions, Pages, 비공개 백업 리포"]
  play["Google Play"]

  learner -->|"앱을 받는다"| play
  learner -->|"문제를 풀고 기록을 백업한다"| system
  operator -->|"문제를 만들고 승인한다, 앱 밖 삭제 요청을 처리한다"| system

  system -->|"로그인"| google
  system -->|"크래시와 이용 통계를 보낸다"| firebase
  system -->|"문제 생성과 검토 (앱 실행 중에는 부르지 않음)"| claude
  system -->|"콘텐츠 게시, 백업, 정적 안내 페이지"| github
```

## 2. 컨테이너

```mermaid
flowchart TB
  learner(["학습자"])
  operator(["운영자"])

  subgraph mannerfit["매너핏"]
    app["Flutter 앱 (Android)<br/>번들 content.json, 기기 안 records.json<br/>XP, 연속 학습일, 복습은 앱에서 계산"]

    subgraph supabase["Supabase (서울 리전)"]
      auth["Auth<br/>Google 로그인 세션"]
      db[("Postgres<br/>attempts, day_completions<br/>RLS로 본인 기록만")]
      storage[("Storage 버킷 content (public)<br/>manifest.json, 버전별 본문")]
      del["Edge Function delete-account<br/>service role을 쓰는 유일한 곳"]
    end

    subgraph actions["GitHub Actions"]
      pipeline["content-pipeline (예정)<br/>매너 id 하나로 문제 3개를 만들어 dev PR"]
      publish["content-publish<br/>main의 content.json을 Storage에 올림"]
      backup["db-backup (비공개 리포)<br/>매일 pg_dump, 30일 보관"]
    end

    pages["GitHub Pages<br/>/privacy/, /delete-account/ 정적 안내"]
  end

  google["Google 로그인"]
  firebase["Firebase<br/>Crashlytics, Analytics"]
  claude["Claude API"]

  learner -->|"문제를 푼다"| app
  learner -->|"처리방침, 삭제 안내를 본다"| pages

  app -->|"ID 토큰을 받는다"| google
  app -->|"ID 토큰으로 세션을 만든다"| auth
  app -->|"기록을 올리고 받는다 (id 기준 합집합)"| db
  app -->|"시작할 때 manifest, 새 본문을 받는다"| storage
  app -->|"탈퇴 (사용자 JWT)"| del
  app -->|"크래시, 최소 이벤트"| firebase

  del -->|"deleteUser, 기록은 cascade로 삭제"| auth
  auth -.->|"사용자 삭제가 기록 삭제로 이어진다"| db

  operator -->|"workflow_dispatch로 매너 id를 넣는다"| pipeline
  pipeline -->|"생성, 블라인드 풀이, 판정"| claude
  pipeline -->|"dev PR을 사람이 머지하고 main에 출시"| publish
  publish -->|"본문 다음 manifest를 올린다"| storage
  backup -->|"pg_dump"| db
  operator -->|"앱 밖 삭제 요청을 대시보드에서 처리"| auth
```

| 컨테이너 | 원본 |
| --- | --- |
| 앱, 기기 안 기록, 동기화 | ADR 0002, 0004, 0005 |
| Postgres, RLS, Auth, `delete-account`, 백업, Pages | ADR 0001 |
| Storage, `content-publish` | ADR 0003 §5 |
| `content-pipeline` | ADR 0009 |
| Firebase | ADR 0006, 0007 |
