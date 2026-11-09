import 'package:flutter/material.dart';
import 'partner_selection_screen.dart';
import 'partner_artwork.dart';
import 'home_screen.dart';
import 'welcome_screen.dart';

class PartnerGrowthScreen extends StatelessWidget {
  const PartnerGrowthScreen({super.key, required this.partner});
  final MannerPartner partner;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F8F8),
    body: SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: '뒤로 가기',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Text(
                '${partner.name}와 함께하는 성장 미리보기',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
                child: Text(
                  '매너를 배우며, ${partner.name}가 이렇게 성장해요.\n언제나 같은 모습으로, 더 멋지게!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Colors.black54,
                  ),
                ),
              ),
              for (final stage in [0, 1, 2, 3])
                Container(
                  height: stage == 3 ? 142 : 111,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE7E8EA)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 126,
                        child: PartnerArtwork(partner: partner, stage: stage),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                ['아기', '유년기', '청소년기', '성체'][stage],
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                [
                                  '호기심 많은 아기 ${partner.name}.\n세상을 배우기 시작해요.',
                                  '매너를 하나씩 배우며\n조금씩 성장해요.',
                                  '다양한 경험을 통해\n더 넓은 세상을 알아가요.',
                                  '멋진 매너 파트너로\n다른 사람에게 좋은 영향을\n주는 존재가 돼요.',
                                ][stage],
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: WelcomeButton(
                  label: '이 파트너 선택하기',
                  primary: true,
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => HomeScreen(partner: partner),
                    ),
                    (_) => false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
