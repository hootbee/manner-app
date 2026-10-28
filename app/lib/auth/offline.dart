// ADR 0007 §2: 전송 오류 = 서버의 응답을 받기 전에 연결에서 끝난 오류. 목록에 있는 것만 오프라인이다.
// auth/와 live/가 함께 쓴다. 새 전송 오류 타입이 보이면 여기에 더한다.
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

bool isOffline(Object e) => switch (e) {
      SocketException() || TlsException() || HttpException() => true, // dart:io: 연결 실패, TLS 실패, 응답 도중 끊김
      ClientException() => true, // package:http: supabase가 쓰는 전송 오류
      TimeoutException() => true, // dart:async: 정한 시간 안에 응답이 없음
      AuthRetryableFetchException(:final statusCode) => statusCode == null, // 상태 코드가 있으면 5xx 응답이다
      FunctionsFetchException(:final details?) => isOffline(details), // 감싼 오류는 안쪽으로 판단한다
      _ => false,
    };
