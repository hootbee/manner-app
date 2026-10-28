// ADR 0007 §2: 전송 오류 목록. 목록에 있는 것만 오프라인이다.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:mannerfit/auth/offline.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final (name, e, want) in <(String, Object, bool)>[
    ('SocketException', const SocketException('down'), true),
    ('TlsException', const TlsException('bad cert'), true),
    ('HttpException', const HttpException('connection closed'), true),
    ('ClientException', ClientException('down'), true),
    ('TimeoutException', TimeoutException('5s'), true),
    ('상태 코드 없는 AuthRetryableFetchException', AuthRetryableFetchException(), true),
    ('FunctionsFetchException(details: ClientException)', FunctionsFetchException(details: ClientException('down')), true),
    ('PostgrestException', const PostgrestException(message: 'rls', code: '42501'), false),
    ('AuthException', const AuthException('bad'), false),
    ('5xx AuthRetryableFetchException', AuthRetryableFetchException(statusCode: '503'), false),
    ('StateError', StateError('bug'), false),
    ('FunctionsFetchException(details: AuthException)', const FunctionsFetchException(details: AuthException('bad')), false),
    ('details 없는 FunctionsFetchException', const FunctionsFetchException(), false),
  ]) {
    test('$name → $want', () => expect(isOffline(e), want));
  }
}
