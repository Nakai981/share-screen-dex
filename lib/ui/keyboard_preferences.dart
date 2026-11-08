import 'package:flutter/material.dart';

import '../domain/workspace.dart';
import 'theme.dart';

extension KeyboardPreference on KeyboardLanguage {
  String get label => switch (this) {
    KeyboardLanguage.system => 'Theo bàn phím trên máy',
    KeyboardLanguage.vietnamese => 'Tiếng Việt',
    KeyboardLanguage.english => 'English',
    KeyboardLanguage.japanese => '日本語',
    KeyboardLanguage.korean => '한국어',
    KeyboardLanguage.chinese => '中文',
  };
  List<Locale>? get hintLocales => switch (this) {
    KeyboardLanguage.system => null,
    KeyboardLanguage.vietnamese => const [Locale('vi', 'VN')],
    KeyboardLanguage.english => const [Locale('en')],
    KeyboardLanguage.japanese => const [Locale('ja')],
    KeyboardLanguage.korean => const [Locale('ko')],
    KeyboardLanguage.chinese => const [Locale('zh')],
  };
}

class KeyboardPreferences extends StatelessWidget {
  const KeyboardPreferences({super.key, required this.workspace});
  final WorkspaceController workspace;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: workspace,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<KeyboardLanguage>(
          key: ValueKey('keyboard-language-${workspace.keyboardLanguage.name}'),
          initialValue: workspace.keyboardLanguage,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Ngôn ngữ nhập',
            prefixIcon: Icon(Icons.language_rounded, size: 20),
          ),
          items: [
            for (final language in KeyboardLanguage.values)
              DropdownMenuItem(
                value: language,
                child: Text(
                  language.label,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
          onChanged: (language) {
            if (language != null) {
              workspace.dispatch({
                'type': 'keyboardLanguage',
                'language': language.name,
              });
            }
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Dùng bộ gõ đã cài trên máy. Nhấn 🌐 hoặc giữ phím cách để đổi bàn phím. iPhone chọn ngôn ngữ bằng phím 🌐; gợi ý ở đây áp dụng cho bàn phím Android có hỗ trợ.',
          style: TextStyle(fontSize: 10, color: AppColors.muted, height: 1.6),
        ),
      ],
    ),
  );
}

/// Preserve the IME's composing range and caret when an unchanged snapshot is
/// echoed from the other Flutter engine. Never modify a live composing region.
class SyncedTextController extends TextEditingController {
  SyncedTextController({required String text})
    : _remote = text,
      super(text: text);
  String _remote;
  void syncRemote(String incoming) {
    if (incoming == _remote) return;
    if (incoming == text) {
      _remote = incoming;
      return;
    }
    if (value.composing.isValid && !value.composing.isCollapsed) return;
    _remote = incoming;
    final old = selection;
    value = TextEditingValue(
      text: incoming,
      selection: old.isValid
          ? TextSelection(
              baseOffset: old.baseOffset.clamp(0, incoming.length),
              extentOffset: old.extentOffset.clamp(0, incoming.length),
            )
          : TextSelection.collapsed(offset: incoming.length),
    );
  }
}
