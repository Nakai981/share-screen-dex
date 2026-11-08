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
    final workspace = widget.workspace;
    final virtualHover = [
      for (var i = 0; i < 4; i++)
        if (workspace.dockItem(i).contains(workspace.cursor)) i,
    ].firstOrNull;
    final hover = mouseHover ?? virtualHover;
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
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xEDF5F8F9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x88FFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40102028),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            _DockTile(
              key: ValueKey('dock-${items[index].$1?.name ?? 'wallpaper'}'),
              label: items[index].$2,
              icon: items[index].$3,
              color: items[index].$4,
              hover: hover == null
                  ? 0
                  : math.max(0, 1 - (index - hover).abs() * .72),
              selected: hover == index,
              active: workspace.activeApp == items[index].$1,
              running: workspace.windows.any((w) => w.app == items[index].$1),
              launches: workspace.launches[items[index].$1] ?? 0,
              onEnter: () => setState(() => mouseHover = index),
              onExit: () => setState(() => mouseHover = null),
              onTap: () => workspace.dispatch(
                items[index].$1 == null
                    ? {'type': 'wallpaper'}
                    : {'type': 'open', 'app': items[index].$1!.name},
              ),
            ),
          ],
        ],
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
  final bool selected;
  final bool active;
  final bool running;
  final int launches;
  final VoidCallback onEnter;
  final VoidCallback onExit;
  final VoidCallback onTap;
  @override
  State<_DockTile> createState() => _DockTileState();
}

class _DockTileState extends State<_DockTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 440),
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
          onTapCancel: () => setState(() => pressed = false),
          onTapUp: (_) => setState(() => pressed = false),
          onTap: widget.onTap,
          child: SizedBox(
            width: 74,
            height: 70,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -39,
                  left: -20,
                  right: -20,
                  child: IgnorePointer(
                    child: AnimatedSlide(
                      offset: widget.selected
                          ? Offset.zero
                          : const Offset(0, .25),
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: widget.selected ? 1 : 0,
                        duration: duration,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.ink,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33102028),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.label,
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
                              -10 * hover -
                                  14 * math.sin(math.pi * bounce.value),
                            ),
                            child: Transform.scale(
                              key: ValueKey('dock-scale-${widget.label}'),
                              scale: pressed ? .9 : 1 + .22 * hover,
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: widget.color,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.color.withValues(
                                        alpha: .12 + .24 * hover,
                                      ),
                                      blurRadius: 4 + 16 * hover,
                                      offset: Offset(0, 2 + 5 * hover),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  widget.icon,
                                  color: Colors.white,
                                  size: 25,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          AnimatedContainer(
                            duration: duration,
                            width: widget.active ? 14 : 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: widget.running
                                  ? widget.color
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(3),
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
