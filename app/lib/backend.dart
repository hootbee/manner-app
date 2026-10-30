// 화면이 보는 인터페이스와 값 타입(ADR 0002 §2). 화면은 이 파일만 import한다.
// 모든 값은 화면에 그대로 그릴 수 있는 모양이다. 풀이 기록, Leitner 단계, 동기화 상태는 드러내지 않는다.
import 'package:flutter/foundation.dart';

late Backend backend; // main.dart와 테스트 setUp에서 넣는다

abstract interface class Backend {
  ValueListenable<Home> get home;
  ValueListenable<List<AreaStat>> get stats; // 영역 6개, 고정 순서
  ValueListenable<Account?> get account; // null이면 게스트
  ValueListenable<bool> get online;
  Session startDaily(); // home.value.today!.doneToday면 부르지 않는다
  Future<SignInResult> signIn();
  Future<SignOutResult> signOut({bool discardUnsynced = false});
  Future<DeleteResult> deleteAccount();
  // 카테고리 연습: 기준이 정해지면 `Session startPractice(String categoryId)` 하나를 더한다.
}

/// today가 null이면 준비된 하루가 없다.
class Home {
  const Home({
    required this.today,
    required this.streak,
    required this.reviewsDue,
    required this.xp,
    required this.level,
    required this.levelProgress,
  });
  final DayCard? today;
  final int streak, reviewsDue, xp, level;
  final double levelProgress;
}

class DayCard {
  const DayCard({
    required this.number,
    required this.title,
    required this.scenes,
    required this.doneToday,
    this.nextTitle,
  });
  final int number;
  final String title;
  final List<SceneCard> scenes;
  final bool doneToday;
  final String? nextTitle;
}

class SceneCard {
  const SceneCard({required this.time, required this.title, required this.short});
  final String time, title, short;
}

/// value는 0~100. 공식은 ADR 0004 §3.
class AreaStat {
  const AreaStat(this.area, this.value);
  final String area;
  final int value;
}

class Account {
  const Account({required this.name, required this.email});
  final String name, email;
}

enum SignInResult { ok, cancelled, offline, failed }

sealed class SignOutResult {
  const SignOutResult();
}

class SignedOut extends SignOutResult {
  const SignedOut();
}

/// 확인받고 discardUnsynced: true로 다시 부른다.
class WouldLose extends SignOutResult {
  const WouldLose(this.count);
  final int count;
}

enum DeleteResult { ok, offline, failed }

/// 세트 하나. Finished 뒤에는 버린다.
abstract interface class Session {
  ValueListenable<Phase> get phase;
  void answer(Answer a); // Asking일 때만 받는다. 두 번째 탭은 무시한다
  void next(); // Intro → Asking, Answered → 다음 문제·장면·Finished. Finished로 갈 때 하루 완료를 기록한다
  void quit(); // 중간 저장 없음. 이미 답한 기록과 XP는 남는다
}

/// progress는 0~1, 진행 바. 다시 풀기가 붙으면 줄 수 있다.
sealed class Phase {
  const Phase(this.progress);
  final double progress;
}

class Intro extends Phase {
  const Intro(super.progress, {required this.dayTitle, required this.intro, required this.scene});
  final String dayTitle, intro;
  final SceneCard scene;
}

/// retry: "다시 풀기" 칩.
class Asking extends Phase {
  const Asking(super.progress, {required this.q, required this.retry});
  final Question q;
  final bool retry;
}

/// 다시 풀기 문제의 nextScene은 null. last는 남은 문제가 없을 때만 참.
class Answered extends Phase {
  const Answered(super.progress, {required this.q, required this.e, required this.nextScene, required this.last});
  final Question q;
  final Explanation e;
  final SceneCard? nextScene;
  final bool last;
}

/// streak: 데일리만.
class Finished extends Phase {
  const Finished({
    required this.xpGained,
    required this.firstTry,
    required this.total,
    required this.bestCombo,
    required this.streak,
    required this.retryTomorrow,
  }) : super(1);
  final int xpGained, firstTry, total, bestCombo;
  final int? streak;
  final List<String> retryTomorrow;
}

/// area: 영역 칩, motto: 원칙 문구.
sealed class Question {
  const Question({required this.area, required this.prompt, required this.motto});
  final String area, prompt, motto;
}

/// vars: mirror, direction 등.
class PositionQuestion extends Question {
  const PositionQuestion({
    required super.area,
    required super.prompt,
    required super.motto,
    required this.template,
    required this.me,
    required this.other,
    required this.vars,
    required this.spots,
  });
  final String template, me, other;
  final Map<String, Object> vars;
  final List<Spot> spots;
}

/// options는 이미 섞인 표시 순서.
class ChoiceQuestion extends Question {
  const ChoiceQuestion({required super.area, required super.prompt, required super.motto, required this.options});
  final List<Option> options;
}

class OxQuestion extends Question {
  const OxQuestion({required super.area, required super.prompt, required super.motto});
}

/// cards는 이미 섞인 순서.
class OrderQuestion extends Question {
  const OrderQuestion({required super.area, required super.prompt, required super.motto, required this.cards});
  final List<Option> cards;
}

class Spot {
  const Spot(this.id, this.label);
  final String id, label;
}

class Option {
  const Option(this.id, this.text);
  final String id, text;
}

sealed class Answer {
  const Answer();
}

class PickSpot extends Answer {
  const PickSpot(this.id);
  final String id;
}

class PickOption extends Answer {
  const PickOption(this.id);
  final String id;
}

class PickOx extends Answer {
  const PickOx(this.o);
  final bool o;
}

class PlaceOrder extends Answer {
  const PlaceOrder(this.ids);
  final List<String> ids;
}

enum Grade { best, ok, avoid }

class Explanation {
  const Explanation({
    required this.grade,
    required this.xp,
    required this.combo,
    required this.title,
    required this.why,
    required this.correct,
    this.options = const {},
    this.evidence,
  });
  final Grade grade;
  final int xp, combo; // xp는 10·5·0. combo는 연출용(보너스 XP 없음)
  final String title, why;
  final List<String> correct; // position [spotId], choice [optionId], ox ['o'|'x'], order 카드 id 순서
  final Map<String, ({Grade grade, String? note})> options; // choice만. 나머지는 빈 맵
  final Evidence? evidence; // 출처가 없으면 null → "근거 보기" 숨김
}

class Evidence {
  const Evidence({required this.summary, required this.sources});
  final String summary;
  final List<Source> sources;
}

class Source {
  const Source({
    required this.title,
    required this.publisher,
    required this.date,
    this.locator,
    required this.url,
  });
  final String title, publisher, date, url;
  final String? locator; // 선택(ADR 0009 §6)
}
