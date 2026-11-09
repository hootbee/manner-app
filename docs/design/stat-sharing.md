# 스탯 카드 저장·공유

- `StatShareScreen`은 전달받은 Home·AreaStat 값으로 카드만 PNG(3배 해상도)로 만든다. 앱바와 버튼은 이미지에 들어가지 않는다.
- 카드 이미지를 먼저 준비하고 버튼을 활성화한다. 준비 중·내보내기 중에는 중복 실행을 막는다.
- 사진 저장: 모바일은 gal, 웹은 XFile.saveTo 다운로드를 사용한다.
- 공유: share_plus 시스템 공유창을 사용한다. 취소는 성공으로 표시하지 않는다. 웹 공유가 불가능하면 저장을 이용하도록 안내한다.
- 현재 프로토타입의 수치는 FakeBackend 샘플이므로 공유 이미지에도 미리보기라고 표시한다. 학습 기록 계산·저장은 변경하지 않는다.

## 플랫폼 확인

Android API 29 이하 저장에 필요한 WRITE_EXTERNAL_STORAGE 권한을 maxSdkVersion=29로 제한해 추가했다. 사용자 사진을 읽는 권한은 요청하지 않는다.

현재 저장소에는 iOS 프로젝트가 없다. 추후 iOS 프로젝트를 추가할 때 Runner/Info.plist에 아래 설명을 넣고 실제 기기에서 저장·권한 거부·공유 취소를 확인한다. iPad 공유창 위치는 버튼 영역으로 전달한다.

```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>매너 스탯 카드를 사진첩에 저장하기 위해 권한이 필요합니다.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>매너 스탯 카드를 사진첩에 저장하기 위해 권한이 필요합니다.</string>
```

기존 Android Gradle Plugin 8.11.1과 호환되는 share_plus 11.1.0을 사용한다. 12 이상으로 올릴 때는 빌드 도구 요구사항을 다시 확인한다.

패키지 설정: [share_plus 11.1.0](https://pub.dev/packages/share_plus/versions/11.1.0), [gal](https://pub.dev/packages/gal).
