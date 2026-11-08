import 'package:flutter_test/flutter_test.dart';
import 'package:side_screen/ui/browser/browser_web_navigation.dart';

void main() {
  test('YouTube home, results and channels use a clear external-tab page', () {
    for (final url in [
      'https://www.youtube.com',
      'https://m.youtube.com/results?search_query=flutter',
      'https://youtube.com/@flutter',
      'https://youtube.com/watch?v=bad',
    ]) {
      expect(needsYouTubeExternalPage(url), true);
    }
  });

  test(
    'watch, short, live and share links use the official player with an origin',
    () {
      for (final url in [
        'https://www.youtube.com/watch?v=M7lc1UVf-VE',
        'https://youtu.be/M7lc1UVf-VE?si=abc',
        'https://m.youtube.com/shorts/M7lc1UVf-VE',
        'https://youtube.com/live/M7lc1UVf-VE',
        'https://www.youtube-nocookie.com/embed/M7lc1UVf-VE',
      ]) {
        final player = youTubePlayerAddress(
          url,
          origin: 'http://127.0.0.1:8765',
        );
        expect(player!.host, 'www.youtube.com');
        expect(player.path, '/embed/M7lc1UVf-VE');
        expect(player.queryParameters['origin'], 'http://127.0.0.1:8765');
        expect(needsYouTubeExternalPage(url), false);
      }
    },
  );

  test(
    'player preserves start times without autoplay or unrelated tracking parameters',
    () {
      final player = youTubePlayerAddress(
        'https://youtu.be/M7lc1UVf-VE?t=1h2m3s&autoplay=1&si=abc',
      )!;
      expect(player.queryParameters['start'], '3723');
      expect(player.queryParameters.containsKey('autoplay'), false);
      expect(player.queryParameters.containsKey('si'), false);
      expect(
        youTubePlayerAddress(
          'https://youtube.com/watch?v=M7lc1UVf-VE&start=90',
        )!.queryParameters['start'],
        '90',
      );
    },
  );

  test('unrelated and spoofed hosts never become YouTube players', () {
    for (final url in [
      'https://youtube.com.evil.test/watch?v=M7lc1UVf-VE',
      'https://notyoutube.com/watch?v=M7lc1UVf-VE',
      'https://example.com',
      'javascript:alert(1)',
      'https://youtube.com/watch?v=../bad',
    ]) {
      expect(youTubePlayerAddress(url), isNull);
    }
  });
}
