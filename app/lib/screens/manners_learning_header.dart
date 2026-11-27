import 'package:flutter/material.dart';

/// Reuses the approved wordmark crop already used by the welcome and home UI.
class MannersLearningHeader extends StatelessWidget {
  const MannersLearningHeader({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Semantics(
          label: '매너스 MANNERS',
          image: true,
          child: const ExcludeSemantics(
            child: SizedBox(
              width: 94,
              height: 47,
              child: FittedBox(
                child: SizedBox(
                  width: 171,
                  height: 85,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: 351,
                      maxWidth: 351,
                      minHeight: 797,
                      maxHeight: 797,
                      child: _WordmarkImage(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: '뒤로 가기',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.chevron_left),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: '알림',
            onPressed: () => ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('새로운 알림이 없어요.'))),
            icon: const Icon(Icons.notifications_none),
          ),
        ),
      ],
    ),
  );
}

class _WordmarkImage extends StatelessWidget {
  const _WordmarkImage();
  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(-89, -91),
    child: Image.asset(
      'assets/welcome/design_reference.webp',
      width: 351,
      height: 797,
      fit: BoxFit.fill,
    ),
  );
}
