import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

enum StatImageResult {
  saved,
  downloaded,
  opened,
  dismissed,
  denied,
  noSpace,
  unsupported,
  failed,
}

typedef StatImageAction =
    Future<StatImageResult> Function(Uint8List png, Rect origin);

/// User-initiated image export only; never reads or changes learning records.
Future<StatImageResult> saveStatImage(Uint8List png, Rect origin) async {
  try {
    if (kIsWeb) {
      await XFile.fromData(
        png,
        mimeType: 'image/png',
        name: 'manners-stats.png',
      ).saveTo('manners-stats.png');
      return StatImageResult.downloaded;
    }
    await Gal.putImageBytes(png, name: 'manners-stats');
    return StatImageResult.saved;
  } on GalException catch (error) {
    return switch (error.type) {
      GalExceptionType.accessDenied => StatImageResult.denied,
      GalExceptionType.notEnoughSpace => StatImageResult.noSpace,
      _ => StatImageResult.failed,
    };
  } on MissingPluginException {
    return StatImageResult.unsupported;
  } catch (_) {
    return StatImageResult.failed;
  }
}

Future<StatImageResult> shareStatImage(Uint8List png, Rect origin) async {
  try {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png')],
        fileNameOverrides: ['manners-stats.png'],
        title: '나의 매너 스탯',
        sharePositionOrigin: origin,
        downloadFallbackEnabled: false,
        mailToFallbackEnabled: false,
      ),
    );
    return result.status == ShareResultStatus.dismissed
        ? StatImageResult.dismissed
        : StatImageResult.opened;
  } on MissingPluginException {
    return StatImageResult.unsupported;
  } catch (_) {
    return StatImageResult.failed;
  }
}
