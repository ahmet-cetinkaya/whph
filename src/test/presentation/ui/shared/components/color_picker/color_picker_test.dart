import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' as flutter_colorpicker;
import 'package:whph/presentation/ui/shared/components/color_picker/color_picker.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';

class MockTranslationService extends Mock implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) {
    if (key == SharedTranslationKeys.colorPickerPaletteTab) return 'Palette';
    if (key == SharedTranslationKeys.colorPickerCustomTab) return 'Custom';
    return key;
  }
}

void main() {
  group('ColorPicker Integration Test', () {
    late MockTranslationService mockTranslationService;

    setUp(() {
      mockTranslationService = MockTranslationService();
    });

    testWidgets('BlockPicker should allow selecting a basic color', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      Color selectedColor = Colors.blue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: ColorPicker(
                    pickerColor: selectedColor,
                    onChangeColor: (color) {
                      setState(() {
                        selectedColor = color;
                      });
                    },
                    translationService: mockTranslationService,
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Verify BlockPicker is present (using flutter_colorpicker package)
      expect(find.byType(flutter_colorpicker.BlockPicker), findsOneWidget);

      // 1. Tap the main Red color swatch.
      // In the BlockPicker, this should select Colors.red immediately.
      final redSwatchFinder = find.byWidgetPredicate((widget) {
        // We look for AnimatedContainer with the color
        if (widget is AnimatedContainer && widget.decoration is BoxDecoration) {
          final decoration = widget.decoration as BoxDecoration;
          if (decoration.color == Colors.red) return true;
        }
        return false;
      });

      expect(redSwatchFinder, findsOneWidget);
      await tester.tap(redSwatchFinder);
      await tester.pumpAndSettle();

      // 2. Verify selection updated to main red color
      expect(selectedColor.toARGB32(), equals(Colors.red.toARGB32()));
    });

    testWidgets('Selected color should always have full alpha', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      Color selectedColor = Colors.white;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 800,
              child: SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: selectedColor,
                  onChangeColor: (color) {
                    selectedColor = color;
                  },
                  translationService: mockTranslationService,
                ),
              ),
            ),
          ),
        ),
      );

      // find Custom tab and switch to it
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      final customPickerFinder = find.byType(flutter_colorpicker.ColorPicker);
      expect(customPickerFinder, findsOneWidget);

      final flutter_colorpicker.ColorPicker picker = tester.widget(customPickerFinder);

      final transparentRed = const Color(0x00FF0000);
      picker.onColorChanged(transparentRed);

      expect((selectedColor.a * 255.0).round() & 0xff, equals(255));
      expect((selectedColor.r * 255.0).round() & 0xff, equals(255));
    });
  });
}
