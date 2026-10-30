# 구조 그림 (C4 컨테이너)

시스템이 어떤 컨테이너로 나뉘고 무엇과 이어지는지만 그린다. 결정과 근거는 [`decisions.md`](decisions.md)와 ADR에 있다. 그림과 다르면 그쪽이 맞고, 이 그림을 고친다.

시스템 컨텍스트(1단계)는 이 그림의 바깥 상자와 같아서 따로 그리지 않는다. 컴포넌트(3단계)와 코드(4단계)도 그리지 않는다. 앱 안 모듈은 [README](../README.md)의 폴더 설명과 ADR 0002 §1이 원본이다.

```mermaid
flowchart TB
  learner(["학습자"])
  operator(["운영자"])

  subgraph mannerfit["매너핏"]
    app["Flutter 앱 (Android)"]

    subgraph supabase["Supabase"]
      auth["Auth"]
      db[("Postgres")]
      storage[("Storage 버킷 content")]
      del["Edge Function delete-account"]
    end

    repo["GitHub 리포<br/>app/assets/content.json"]

    subgraph actions["GitHub Actions"]
      pipeline["content-pipeline (예정)"]
      publish["content-publish"]
      backup["db-backup (비공개 리포)"]
    end

    pages["GitHub Pages<br/>/privacy/, /delete-account/"]
  end

  google["Google 로그인"]
  firebase["Firebase<br/>Crashlytics, Analytics"]
  claude["Claude API"]

  learner -->|"문제를 푼다"| app
  learner -->|"처리방침, 삭제 안내를 본다"| pages

  app -->|"ID 토큰"| google
  app -->|"로그인 세션"| auth
  app -->|"풀이 기록, 완료 기록"| db
  app -->|"새 콘텐츠"| storage
  app -->|"탈퇴 요청"| del
  app -->|"크래시, 이벤트"| firebase
  app -->|"처리방침 링크"| pages

  del -->|"사용자 삭제"| auth
  auth -.->|"사용자 삭제가 기록 삭제로 이어진다"| db

  operator -->|"매너 id로 실행"| pipeline
  pipeline -->|"문제 생성, 검토"| claude
  pipeline -->|"dev PR"| repo
  operator -->|"PR 머지, main 출시"| repo
  repo -->|"main push"| publish
  publish -->|"콘텐츠 파일"| storage
  backup -->|"pg_dump"| db
  backup -->|"pg_dump"| auth
  operator -->|"앱 밖 삭제 요청 처리"| auth
```

| 컨테이너 | 원본 |
| --- | --- |
| 앱, 기기 안 기록, 동기화 | ADR 0001 §3, 0002, 0005 |
| Postgres, Auth, `delete-account`, 백업, Pages | ADR 0001 |
| Storage, `content-publish` | ADR 0003 §5 |
| `content-pipeline` | ADR 0009 |
| Firebase | ADR 0006, 0007 |
