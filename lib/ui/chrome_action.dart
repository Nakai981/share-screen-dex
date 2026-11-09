import 'package:flutter/material.dart';

import '../domain/workspace.dart';
import '../platform/chrome_launcher.dart';

Future<void> openChromeFromPhone(
  BuildContext context,
  WorkspaceController workspace,
) async {
  try {
    await ChromeLauncher.open(
      workspace.activeApp == DeskApp.browser
          ? workspace.browserUrl
          : browserHome,
    );
  } on ChromeLaunchException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class ChromePhoneAction extends StatelessWidget {
  const ChromePhoneAction({super.key, required this.workspace});
  final WorkspaceController workspace;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        key: const ValueKey('phone-open-chrome'),
        onPressed: ChromeLauncher.supported
            ? () => openChromeFromPhone(context, workspace)
            : null,
        icon: const Icon(Icons.open_in_browser_rounded, size: 18),
        label: const Text('Mở trang này bằng Chrome'),
      ),
      const SizedBox(height: 4),
      const Text(
        'Chrome mở riêng trên điện thoại. Quay lại SideScreen để tiếp tục desktop.',
        style: TextStyle(fontSize: 10, color: Color(0xFF637783)),
      ),
    ],
  );
}
