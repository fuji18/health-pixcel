import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/domain/goal_input.dart';

void main() {
  const notNumber = '数字で入力してください';
  const stepsRange = '1,000〜100,000 歩の範囲で入力してください';

  group('parseStepsGoal', () {
    test('空文字・空白のみは目標なし', () {
      expect(parseStepsGoal(''), (value: null, error: null));
      expect(parseStepsGoal('  '), (value: null, error: null));
    });

    test('半角・全角・カンマ付きを解釈する', () {
      for (final s in ['8000', '8,000', '８０００', '８，０００']) {
        expect(parseStepsGoal(s), (value: 8000, error: null), reason: s);
      }
    });

    test('境界', () {
      expect(parseStepsGoal('1000').value, 1000);
      expect(parseStepsGoal('100000').value, 100000);
      expect(parseStepsGoal('999'), (value: null, error: stepsRange));
      expect(parseStepsGoal('100001'), (value: null, error: stepsRange));
    });

    test('数字以外', () {
      for (final s in ['abc', '8000.5', '-100']) {
        expect(parseStepsGoal(s), (value: null, error: notNumber), reason: s);
      }
    });

    test('桁が多すぎる値は範囲外', () {
      expect(parseStepsGoal('99999999999999999999999'), (
        value: null,
        error: stepsRange,
      ));
    });
  });

  group('parseSleepGoal', () {
    test('両方空は目標なし', () {
      expect(parseSleepGoal('', ''), (
        minutes: null,
        hoursError: null,
        minutesError: null,
      ));
    });

    test('正常値', () {
      expect(parseSleepGoal('7', '').minutes, 420);
      expect(parseSleepGoal('7', '30').minutes, 450);
      expect(parseSleepGoal('3', '0').minutes, 180);
      expect(parseSleepGoal('12', '0').minutes, 720);
      expect(parseSleepGoal('７', '３０').minutes, 450);
    });

    test('範囲外', () {
      const err = '3〜12 時間の範囲で入力してください';
      expect(parseSleepGoal('2', '59'), (
        minutes: null,
        hoursError: err,
        minutesError: null,
      ));
      expect(parseSleepGoal('12', '1').hoursError, err);
    });

    test('時間が空で分だけ', () {
      expect(parseSleepGoal('', '30').hoursError, '時間を入力してください');
    });

    test('分が 60 以上', () {
      expect(parseSleepGoal('7', '60').minutesError, '0〜59 分で入力してください');
    });

    test('数字以外は両方のエラーを返す', () {
      expect(parseSleepGoal('a', 'b'), (
        minutes: null,
        hoursError: notNumber,
        minutesError: notNumber,
      ));
    });
  });
}
