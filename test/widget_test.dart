import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:side_screen/app.dart';
import 'package:side_screen/platform/display_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in [
    const Size(320, 740),
    const Size(390, 844),
    const Size(1024, 768),
    const Size(1440, 1000),
  ]) {
    testWidgets(
      'controller fits ${size.width} × ${size.height} without overflows',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(const SideScreenApp());
        await tester.pumpAndSettle();
        expect(find.text('SideScreen').first, findsOneWidget);
        expect(find.text('Bạn đang dùng chế độ xem thử.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('phone keyboard writes into the desktop preview', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const SideScreenApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('phone-notes')),
      'Xin chào màn hình lớn!',
    );
    await tester.pumpAndSettle();
    final desktop = tester.widget<TextField>(
      find.byKey(const ValueKey('desktop-notes')),
    );
    expect(desktop.controller!.text, 'Xin chào màn hình lớn!');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('native bootstrap displays physical monitor information', (
    tester,
  ) async {
    const channel = MethodChannel(DisplayBridge.channelName);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'initialize') {
        return {
          'status': {
            'nativeAvailable': true,
            'connected': true,
            'presenting': true,
            'name': 'HDMI Display',
            'width': 1920,
            'height': 1080,
          },
        };
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(const SideScreenApp());
    await tester.pumpAndSettle();
    expect(find.text('Màn hình đã sẵn sàng'), findsOneWidget);
    expect(find.text('HDMI Display\n1920 × 1080'), findsOneWidget);
    expect(find.text('Bàn điều khiển'), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const ValueKey('touchpad'))).bottom,
      lessThan(tester.view.physicalSize.height),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
