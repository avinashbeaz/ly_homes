import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ly_homes/models/device.dart';
import 'package:ly_homes/screens/dashboard_screen.dart';
import 'package:ly_homes/services/preview_repository.dart';
import 'package:ly_homes/theme/app_theme.dart';
import 'package:ly_homes/widgets/device_tile.dart';

Widget tile({
  required Future<void> Function(bool) toggle,
  bool available = true,
  double scale = 1,
}) => MaterialApp(
  theme: AppTheme.build(Brightness.light),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: SingleChildScrollView(
        child: DeviceTile(
          device: Device(id: '1', name: 'Living room ceiling light'),
          available: available,
          onToggle: toggle,
          onRename: () {},
          onDelete: () {},
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('Pending command blocks duplicate taps and times out honestly', (
    tester,
  ) async {
    final completion = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      tile(
        toggle: (_) {
          calls++;
          return completion.future;
        },
      ),
    );
    await tester.tap(find.text('Living room ceiling light'));
    await tester.pump();
    expect(find.text('Saving command…'), findsOneWidget);
    await tester.tap(find.text('Living room ceiling light'));
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Couldn’t save. Tap to retry'), findsOneWidget);
    completion.complete();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Unavailable room disables device commands at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var calls = 0;
    await tester.pumpWidget(
      tile(
        toggle: (_) async {
          calls++;
        },
        available: false,
        scale: 2,
      ),
    );
    await tester.tap(find.text('Living room ceiling light'));
    expect(calls, 0);
    expect(find.text('Room unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Home favourites, rooms and current alerts navigate without Firebase',
    (tester) async {
      final repository = PreviewRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(Brightness.light),
          home: DashboardScreen(repository: repository, preview: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Favourites'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Favourites'), findsOneWidget);
      await tester.tap(find.text('Alerts'));
      await tester.pumpAndSettle();
      expect(find.text('Needs attention'), findsOneWidget);
      await tester.tap(find.text('Bedroom'));
      await tester.pumpAndSettle();
      expect(find.text('Controller isn’t responding'), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Larger text'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await repository.dispose();
    },
  );
  testWidgets('Mobile dashboard reflows at 200 percent text in dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = PreviewRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: DashboardScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Rooms'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await repository.dispose();
  });
}
