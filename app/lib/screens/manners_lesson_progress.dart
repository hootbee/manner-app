import 'package:flutter/material.dart';

/// Approved action-lesson progress layout, reused without changing 01/02.
class MannersLessonProgress extends StatelessWidget {
  const MannersLessonProgress({
    super.key,
    required this.number,
    this.application = false,
  });
  final int number;
  final bool application;
  String get label => application
      ? '응용 ${number.toString().padLeft(2, "0")}/20 · 2/2'
      : '기본 문제 ${number.toString().padLeft(2, "0")}/20';
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.textScalerOf(context).scale(14) > 14) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          border: Border.all(color: const Color(0xFFE7E7E7)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.directions_subway),
                const Text(
                  '대중교통',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (number) / 20,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF191D1A),
              backgroundColor: const Color(0xFFE4E4E4),
            ),
          ],
        ),
      );
    }
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        border: Border.all(color: const Color(0xFFE7E7E7)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: application ? 380 : 340,
          child: Row(
            children: [
              const CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFFECECEC),
                child: Icon(
                  Icons.directions_subway,
                  color: Colors.black,
                  size: 23,
                ),
              ),
              const SizedBox(height: 24, child: VerticalDivider(width: 16)),
              const Text(
                '대중교통',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEDED),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LinearProgressIndicator(
                  value: (number) / 20,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFF191D1A),
                  backgroundColor: const Color(0xFFE4E4E4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
