// lib/reader/epub_reader_page.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epub_view/epub_view.dart';

import 'package:book_hub/services/reader_prefs.dart';

class EpubReaderPage extends StatefulWidget {
  final String bookId; // use real backend ID when ready
  final String? filePath; // for downloaded .epub
  final String? assetPath; // for bundled asset .epub
  final int initialChapterIndex;
  final ReaderThemeMode theme;

  const EpubReaderPage({
    super.key,
    required this.bookId,
    this.filePath,
    this.assetPath,
    this.initialChapterIndex = 0,
    this.theme = ReaderThemeMode.light,
  }) : assert(
         (filePath != null) ^ (assetPath != null),
         'Provide either filePath or assetPath, not both',
       );

  @override
  State<EpubReaderPage> createState() => _EpubReaderPageState();
}

class _EpubReaderPageState extends State<EpubReaderPage> {
  EpubController? _controller;
  String? _savedCfi;
  int _lastChapterIdx = 0;
  Color? _customBg;
  Color? _customText;
  Timer? _cfiDebounce;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _cfiDebounce?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _savedCfi = prefs.getString(_kCfi(widget.bookId));
    _lastChapterIdx =
        prefs.getInt(_kChapter(widget.bookId)) ?? widget.initialChapterIndex;

    if (widget.theme == ReaderThemeMode.custom) {
      final bg = await ReaderPrefs.getCustomBg();
      final tx = await ReaderPrefs.getCustomText();
      if (bg != null) _customBg = Color(bg);
      if (tx != null) _customText = Color(tx);
    }

    final doc =
        widget.filePath != null
            ? EpubDocument.openFile(File(widget.filePath!))
            : EpubDocument.openAsset(widget.assetPath!);

    final ctrl = EpubController(document: doc);
    if (!mounted) return; // 👈 guard
    setState(() => _controller = ctrl);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_savedCfi != null && _savedCfi!.isNotEmpty) {
        // gotoEpubCfi returns void in epub_view → no await
        try {
          ctrl.gotoEpubCfi(_savedCfi!); // ok
          return;
        } catch (_) {
          /* ignore bad/old CFIs */
        }
      }
      if (_lastChapterIdx > 0) {
        ctrl.scrollTo(index: _lastChapterIdx);
      }
    });
  }

  Future<void> _persistCfi(String cfi) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCfi(widget.bookId), cfi);
  }

  Future<void> _persistChapter(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kChapter(widget.bookId), index);
  }

  bool _onAnyScroll(EpubController ctrl) {
    final cfi = ctrl.generateEpubCfi();
    if (cfi == null || cfi.isEmpty) return false;
    _cfiDebounce?.cancel();
    _cfiDebounce = Timer(const Duration(milliseconds: 350), () {
      _persistCfi(cfi);
    });
    return false;
  }

  static String _kCfi(String id) => 'epub_last_cfi_$id';
  static String _kChapter(String id) => 'epub_last_chapter_$id';

  _ReaderChromeColors _mapTheme(BuildContext context) {
    if (widget.theme == ReaderThemeMode.custom &&
        _customBg != null &&
        _customText != null) {
      return _ReaderChromeColors(
        background: _customBg!,
        surface: _customBg!,
        text: _customText!,
        textSecondary: _customText!.withAlpha(180),
        divider: const Color(0x22000000),
        progressBg: const Color(0x11000000),
      );
    }
    switch (widget.theme) {
      case ReaderThemeMode.dark:
        return _ReaderChromeColors(
          background: const Color(0xFF111111),
          surface: const Color(0xFF1A1A1A),
          text: const Color(0xFFECECEC),
          textSecondary: const Color(0xFFBFBFBF),
          divider: const Color(0xFF2A2A2A),
          progressBg: const Color(0xFF2A2A2A),
        );
      case ReaderThemeMode.sepia:
        return _ReaderChromeColors(
          background: const Color(0xFFFFF7E6),
          surface: const Color(0xFFFFF1D6),
          text: const Color(0xFF3F2F1E),
          textSecondary: const Color(0xFF7A6A55),
          divider: const Color(0xFFE8DABE),
          progressBg: const Color(0xFFEADFC8),
        );
      case ReaderThemeMode.light:
      default:
        return _ReaderChromeColors(
          background: Colors.white,
          surface: Colors.white,
          text: Colors.black87,
          textSecondary: Colors.black54,
          divider: const Color(0x14000000),
          progressBg: const Color(0x11000000),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _mapTheme(context);
    final ctrl = _controller;
    if (ctrl == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        title: EpubViewActualChapter(
          controller: ctrl,
          builder:
              (chapterValue) => Text(
                (chapterValue?.chapter?.Title ?? 'Reader')
                    .replaceAll('\n', '')
                    .trim(),
                overflow: TextOverflow.ellipsis,
              ),
        ),
        actions: [
          // Use dynamic to avoid version/type-name mismatches
          ValueListenableBuilder<dynamic>(
            valueListenable: ctrl.currentValueListenable,
            builder: (context, _, __) {
              final v = ctrl.currentValueListenable.value; // dynamic
              final pct = (((v?.progress ?? 0.0) as num).toDouble() * 100)
                  .clamp(0, 100);
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: TextStyle(color: c.text),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(child: EpubViewTableOfContents(controller: ctrl)),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (_) => _onAnyScroll(ctrl),
        child: EpubView(
          controller: ctrl,
          onDocumentLoaded: (_) {},
          onChapterChanged: (value) {
            final idx = (value as dynamic).chapterNumber ?? 0;
            _persistChapter((idx as num).toInt());
          },
        ),
      ),
      bottomNavigationBar: _BottomBar(controller: ctrl, colors: c),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final EpubController controller;
  final _ReaderChromeColors colors;
  const _BottomBar({required this.controller, required this.colors});

  void _goChapterDelta(int delta) {
    final toc =
        controller.tableOfContentsListenable.value; // List<EpubViewChapter>
    if (toc.isEmpty) return;

    final curr =
        (controller.currentValueListenable.value as dynamic)?.chapterNumber ??
        0;
    final next = (curr + delta).clamp(0, toc.length - 1);

    final startIndex = (toc[next].startIndex ?? 0).clamp(0, 1 << 20);
    controller.jumpTo(index: startIndex);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<dynamic>(
              valueListenable: controller.currentValueListenable,
              builder: (context, _, __) {
                final v = controller.currentValueListenable.value; // dynamic
                final chapterProgress = ((v?.progress ?? 0.0) as num)
                    .toDouble()
                    .clamp(0, 1);
                final chapterPct = (chapterProgress * 100).toStringAsFixed(0);

                final tocLen =
                    controller.tableOfContentsListenable.value.length;
                final chapterIdx = ((v?.chapterNumber ?? 0) as num).toInt();
                final overall =
                    tocLen > 0 ? (chapterIdx / tocLen).clamp(0, 1) : 0.0;

                final title =
                    (v?.chapter?.Title ?? '—')
                        .toString()
                        .replaceAll('\n', '')
                        .trim();

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: chapterProgress.toDouble(),
                            backgroundColor: colors.progressBg,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$chapterPct%',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: overall.toDouble(),
                            backgroundColor: colors.progressBg,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Ch ${chapterIdx + 1}/$tocLen · $title',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _goChapterDelta(-1),
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _goChapterDelta(1),
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderChromeColors {
  final Color background;
  final Color surface;
  final Color text;
  final Color textSecondary;
  final Color divider;
  final Color progressBg;
  _ReaderChromeColors({
    required this.background,
    required this.surface,
    required this.text,
    required this.textSecondary,
    required this.divider,
    required this.progressBg,
  });
}
