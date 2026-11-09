import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../domain/workspace.dart';
import 'theme.dart';

class DesktopDock extends StatefulWidget {
  const DesktopDock({super.key, required this.workspace});
  final WorkspaceController workspace;
  @override
  State<DesktopDock> createState() => _DesktopDockState();
}

class _DesktopDockState extends State<DesktopDock> {
  int? mouseHover;
  @override
  Widget build(BuildContext context) {
    final w = widget.workspace;
    final virtual = [
      for (var i = 0; i < 4; i++)
        if (w.dockItem(i).contains(w.cursor)) i,
    ].firstOrNull;
    final hover = mouseHover ?? virtual;
    final items = [
      (DeskApp.notes, 'Ghi chú', Icons.edit_note_rounded, AppColors.blue),
      (
        DeskApp.browser,
        'Trình duyệt',
        Icons.public_rounded,
        const Color(0xFF378A8E),
      ),
      (
        DeskApp.guide,
        'Bắt đầu',
        Icons.auto_awesome_rounded,
        const Color(0xFF358677),
      ),
      (null, 'Hình nền', Icons.palette_outlined, const Color(0xFFB57960)),
    ];
    return SizedBox(
      width: w.dockRect.width,
      height: w.dockRect.height,
      child: FittedBox(
        fit: BoxFit.fill,
        child: Container(
          key: const ValueKey('desktop-taskbar'),
          width: 320,
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          color: Colors.transparent,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _DockTile(
                  key: ValueKey('dock-${items[i].$1?.name ?? 'wallpaper'}'),
                  label: items[i].$2,
                  icon: items[i].$3,
                  color: items[i].$4,
                  hover: hover == null
                      ? 0
                      : math.max(0, 1 - (i - hover).abs() * .8),
                  selected: hover == i,
                  active: w.activeApp == items[i].$1,
                  running: w.windows.any((window) => window.app == items[i].$1),
                  launches: w.launches[items[i].$1] ?? 0,
                  onEnter: () => setState(() => mouseHover = i),
                  onExit: () => setState(() => mouseHover = null),
                  onTap: () => w.dispatch(
                    items[i].$1 == null
                        ? {'type': 'wallpaper'}
                        : {'type': 'open', 'app': items[i].$1!.name},
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DockTile extends StatefulWidget {
  const _DockTile({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.hover,
    required this.selected,
    required this.active,
    required this.running,
    required this.launches,
    required this.onEnter,
    required this.onExit,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final double hover;
  final bool selected, active, running;
  final int launches;
  final VoidCallback onEnter, onExit, onTap;
  @override
  State<_DockTile> createState() => _DockTileState();
}

class _DockTileState extends State<_DockTile>
    with SingleTickerProviderStateMixin {
  late final bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );
  bool pressed = false;
  @override
  void didUpdateWidget(_DockTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.launches != oldWidget.launches &&
        !MediaQuery.disableAnimationsOf(context)) {
      bounce.forward(from: 0);
    }
  }

  @override
  void dispose() {
    bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 140);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => widget.onEnter(),
      onExit: (_) => widget.onExit(),
      child: Semantics(
        label: widget.label,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => pressed = true),
          onTapUp: (_) => setState(() => pressed = false),
          onTapCancel: () => setState(() => pressed = false),
          onTap: widget.onTap,
          child: SizedBox(
            width: 64,
            height: 56,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -37,
                  left: -30,
                  right: -30,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: widget.selected ? 1 : 0,
                      duration: duration,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: bounce,
                    builder: (context, _) => TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: widget.hover),
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      builder: (context, hover, _) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Transform.translate(
                            offset: Offset(
                              0,
                              -6 * hover - 8 * math.sin(math.pi * bounce.value),
                            ),
                            child: Transform.scale(
                              key: ValueKey('dock-scale-${widget.label}'),
                              scale: pressed ? .9 : 1 + .18 * hover,
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: widget.color,
                                  borderRadius: BorderRadius.circular(13),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x35102028),
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  widget.icon,
                                  size: 28,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          AnimatedContainer(
                            duration: duration,
                            width: widget.active ? 12 : 4,
                            height: 3,
                            decoration: BoxDecoration(
                              color: widget.running
                                  ? widget.color
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
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
}
