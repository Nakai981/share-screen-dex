import 'package:flutter/material.dart';

import '../domain/workspace.dart';
import 'desktop.dart';

/// Only the actual external view (or an explicitly expanded preview) reports
/// its viewport. Rotating the phone must not resize the attached monitor.
class DesktopViewport extends StatefulWidget {
  const DesktopViewport({
    super.key,
    required this.workspace,
    this.reportSize = true,
    this.showChrome = true,
  });
  final WorkspaceController workspace;
  final bool reportSize;
  final bool showChrome;
  @override
  State<DesktopViewport> createState() => _DesktopViewportState();
}

class _DesktopViewportState extends State<DesktopViewport> {
  Size? reported;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      if (widget.reportSize &&
          size.isFinite &&
          !size.isEmpty &&
          reported != size) {
        reported = size;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && reported == size) {
            widget.workspace.dispatch({
              'type': 'displayViewport',
              'source': 'renderer',
              'width': size.width,
              'height': size.height,
            });
          }
        });
      }
      return DesktopView(
        workspace: widget.workspace,
        showChrome: widget.showChrome,
      );
    },
  );
}
