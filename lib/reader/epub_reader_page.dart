// lib/reader/epub_reader_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epub_view/epub_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:book_hub/features/reading/reading_providers.dart';
import 'package:book_hub/features/reading/reading_repository.dart';
import 'package:book_hub/features/reading/reading_models.dart';
import 'package:book_hub/services/reader_prefs.dart';
import 'package:book_hub/services/storage/reading_history_store.dart';
import 'package:book_hub/models/history_entry.dart';

/// ======================
///  Session / Progress I/O
/// ======================
class _ReaderSession {
  final String bookId;
  final ReadingRepository repo;

  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);
  Map<String, dynamic>? _lastLocator;
  double _lastPercent = 0.0;

  _ReaderSession({required this.bookId, required this.repo});

  Future<void> onOpen() async {
    try {
      await repo.logHistory(bookId);
    } catch (_) {}
  }

  Future<ReadingProgressDto?> loadProgress() async {
    try {
      return await repo.getProgress(bookId);
    } catch (_) {
      return null;
    }
  }

  /// Throttled to ~10s and requires a valid CFI
  Future<void> onPosition({
    required double percent,
    Map<String, dynamic>? locator,
  }) async {
    _lastPercent = percent.clamp(0.0, 1.0);

    if (locator == null || (locator['cfi'] as String?)?.isEmpty == true) {
      return;
    }
    _lastLocator = locator;

    final now = DateTime.now();
    if (now.difference(_lastSave).inSeconds >= 10) {
      _lastSave = now;
      try {
        await repo.saveProgress(
          bookId,
          percent: _lastPercent,
          locator: _lastLocator,
          format: 'epub',
        );
      } catch (_) {}
    }
  }

  Future<void> onClose() async {
    if (_lastLocator == null ||
        (_lastLocator!['cfi'] as String?)?.isEmpty == true) {
      return;
    }
    try {
      await repo.saveProgress(
        bookId,
        percent: _lastPercent,
        locator: _lastLocator,
        format: 'epub',
      );
    } catch (_) {}
  }
}

/// ======================
///  Reader Page
/// ======================
class EpubReaderPage extends ConsumerStatefulWidget {
  final String bookId;

  /// Mutually exclusive sources (exactly one must be non-null)
  final String? filePath;
  final String? assetPath;
  final Uint8List? bytesData;

  final int initialChapterIndex;
  final ReaderThemeMode theme; // initial theme
  final String? bookTitle;
  final String? author;
  final String? coverUrl;

  /// 👇 NEW: hide only the visual progress (bars/%), keep sync logic intact.
  final bool showProgressUI;

  const EpubReaderPage({
    super.key,
    required this.bookId,
    this.filePath,
    this.assetPath,
    this.bytesData,
    this.initialChapterIndex = 0,
    this.theme = ReaderThemeMode.light,
    this.bookTitle,
    this.author,
    this.coverUrl,
    this.showProgressUI = true, // default keeps current behavior
  }) : assert(
         (filePath != null ? 1 : 0) +
                 (assetPath != null ? 1 : 0) +
                 (bytesData != null ? 1 : 0) ==
             1,
         'Provide exactly one of: filePath, assetPath, or bytesData',
       );

  @override
  ConsumerState<EpubReaderPage> createState() => _EpubReaderPageState();
}

class _EpubReaderPageState extends ConsumerState<EpubReaderPage> {
  EpubController? _controller;
  String? _savedCfi;
  int _lastChapterIdx = 0;

  // THEME: editable at runtime
  ReaderThemeMode _themeMode = ReaderThemeMode.light;
  Color? _customBg;
  Color? _customText;

  // Typography (persisted)
  double _fontScale = 1.0; // A-/A+ (0.8 .. 1.6)
  double _lineHeight = 1.55; // line spacing (1.2 .. 2.0)
  double _letterSpacing = 0.0; // “word space” proxy
  TextAlign _textAlign = TextAlign.left;

  Timer? _cfiDebounce;
  _ReaderSession? _session;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.theme; // seed from opener
    _bootstrap();
  }

  @override
  void dispose() {
    _cfiDebounce?.cancel();
    final s = _session;
    if (s != null) {
      s.onClose();
    }
    _controller?.dispose();
    super.dispose();
  }

  /// 1-based -> 0-based, clamped (epub_view is 1-based)
  int _zeroBasedChapter(dynamic v, {required int tocLen}) {
    final raw = ((v?.chapterNumber ?? 1) as num).toInt();
    return raw <= 0 ? 0 : (raw - 1).clamp(0, tocLen > 0 ? tocLen - 1 : 0);
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();

    // restore last pos
    _savedCfi = prefs.getString(_kCfi(widget.bookId));
    _lastChapterIdx =
        prefs.getInt(_kChapter(widget.bookId)) ?? widget.initialChapterIndex;

    // restore typography
    _fontScale = prefs.getDouble('reader_fontScale') ?? 1.0;
    _lineHeight = prefs.getDouble('reader_lineHeight') ?? 1.55;
    _letterSpacing = prefs.getDouble('reader_letterSpacing') ?? 0.0;
    final alignStr = prefs.getString('reader_textAlign') ?? 'left';
    _textAlign = switch (alignStr) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      'justify' => TextAlign.justify,
      _ => TextAlign.left,
    };

    // restore theme (custom colors if any)
    if (_themeMode == ReaderThemeMode.custom) {
      final bg = await ReaderPrefs.getCustomBg();
      final tx = await ReaderPrefs.getCustomText();
      if (bg != null) _customBg = Color(bg);
      if (tx != null) _customText = Color(tx);
    }

    // Build the Future<EpubBook> from the chosen source.
    late final Future<EpubBook> doc;
    if (widget.bytesData != null) {
      doc = EpubDocument.openData(widget.bytesData!); // live from memory
    } else if (widget.filePath != null) {
      doc = EpubDocument.openFile(File(widget.filePath!));
    } else {
      doc = EpubDocument.openAsset(widget.assetPath!);
    }

    final ctrl = EpubController(document: doc);
    if (!mounted) return;
    setState(() => _controller = ctrl);

    // Local history snapshot
    try {
      final store = ref.read(readingHistoryStoreProvider);
      await store.upsert(
        HistoryEntry(
          bookId: widget.bookId,
          title:
              widget.bookTitle ??
              (ctrl.currentValueListenable.value?.chapter?.Title
                      ?.toString()
                      .replaceAll('\n', '')
                      .trim() ??
                  'Book'),
          author: widget.author ?? '',
          coverUrl: widget.coverUrl,
          openedAtMillis: DateTime.now().millisecondsSinceEpoch,
          chapterIndex: _lastChapterIdx,
          scrollProgress: 0.0,
        ),
      );
    } catch (_) {}

    // backend session
    final repo = ref.read(readingRepositoryProvider);
    _session = _ReaderSession(bookId: widget.bookId, repo: repo);

    // resume position
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _session?.onOpen();

      final serverProg = await _session?.loadProgress();
      final serverCfi = serverProg?.locator?['cfi']?.toString();
      final serverPercent = serverProg?.percent ?? 0.0;

      try {
        if (serverCfi != null && serverCfi.isNotEmpty) {
          ctrl.gotoEpubCfi(serverCfi);
          return;
        }
      } catch (_) {}

      if (_savedCfi != null && _savedCfi!.isNotEmpty) {
        try {
          ctrl.gotoEpubCfi(_savedCfi!);
          return;
        } catch (_) {}
      }

      if (serverCfi == null && serverPercent > 0) {
        final tocLen = ctrl.tableOfContentsListenable.value.length;
        if (tocLen > 0) {
          final approxChapter = (serverPercent.clamp(0.0, 1.0) * tocLen)
              .floor()
              .clamp(0, tocLen - 1);
          ctrl.scrollTo(index: approxChapter);
          return;
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

  Future<void> _persistTypography() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('reader_fontScale', _fontScale);
    await p.setDouble('reader_lineHeight', _lineHeight);
    await p.setDouble('reader_letterSpacing', _letterSpacing);
    await p.setString('reader_textAlign', switch (_textAlign) {
      TextAlign.center => 'center',
      TextAlign.right => 'right',
      TextAlign.justify => 'justify',
      _ => 'left',
    });
  }

  Map<String, dynamic> _buildLocator(EpubController ctrl, String cfi) {
    final v = ctrl.currentValueListenable.value as dynamic;
    final tocLen = _controller?.tableOfContentsListenable.value.length ?? 0;
    final chapterIdx0 = _zeroBasedChapter(v, tocLen: tocLen);
    return {'cfi': cfi, 'chapter': chapterIdx0};
  }

  double _overallPercent(dynamic v) {
    final tocLen = _controller?.tableOfContentsListenable.value.length ?? 0;
    final within =
        ((v?.progress ?? 0) as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.0;
    if (tocLen <= 0) return within;

    final chapterIdx0 = _zeroBasedChapter(v, tocLen: tocLen);
    final base = chapterIdx0 / tocLen; // each chapter is 1/tocLen
    return (base + within / tocLen).clamp(0.0, 1.0);
  }

  double _chapterPercent(dynamic v) {
    final p = ((v?.progress) as num?)?.toDouble();
    if (p != null) return p.clamp(0.0, 1.0); // use given 0..1 if present

    final tocLen = _controller?.tableOfContentsListenable.value.length ?? 0;
    if (tocLen <= 0) return 0.0;

    final chapterIdx0 = _zeroBasedChapter(v, tocLen: tocLen);
    final overall = _overallPercent(v);
    final base = chapterIdx0 / tocLen;
    final nextBase = (chapterIdx0 + 1) / tocLen;
    final span = nextBase - base;
    if (span <= 0) return 0.0;

    return ((overall - base) / span).clamp(0.0, 1.0);
  }

  double _getOverallPercentForSession(EpubController ctrl) {
    return _overallPercent(ctrl.currentValueListenable.value);
  }

  bool _onAnyScroll(EpubController ctrl) {
    final cfi = ctrl.generateEpubCfi();
    if (cfi == null || cfi.isEmpty) return false;

    _cfiDebounce?.cancel();
    _cfiDebounce = Timer(const Duration(milliseconds: 350), () async {
      await _persistCfi(cfi);

      try {
        final store = ref.read(readingHistoryStoreProvider);
        final v = ctrl.currentValueListenable.value as dynamic;
        final tocLen = _controller?.tableOfContentsListenable.value.length ?? 0;
        final chapterIdx0 = _zeroBasedChapter(v, tocLen: tocLen);
        await store.upsert(
          HistoryEntry(
            bookId: widget.bookId,
            title: widget.bookTitle ?? 'Book',
            author: widget.author ?? '',
            coverUrl: widget.coverUrl,
            openedAtMillis: DateTime.now().millisecondsSinceEpoch,
            chapterIndex: chapterIdx0,
            scrollProgress: _getOverallPercentForSession(ctrl),
          ),
        );
      } catch (_) {}

      final s = _session;
      if (s != null) {
        final pct = _getOverallPercentForSession(ctrl);
        final loc = _buildLocator(ctrl, cfi);
        s.onPosition(percent: pct, locator: loc);
      }
    });
    return false;
  }

  static String _kCfi(String id) => 'epub_last_cfi_$id';
  static String _kChapter(String id) => 'epub_last_chapter_$id';

  /// ======================
  ///  Theme mapping
  /// ======================
  _ReaderChromeColors _mapTheme(BuildContext context) {
    if (_themeMode == ReaderThemeMode.custom &&
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
    switch (_themeMode) {
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

  /// ======================
  ///  Settings Sheet (Theme + Typography)
  /// ======================
  Future<void> _openSettingsSheet() async {
    final picked = await showModalBottomSheet<_ThemePickResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder:
          (_) => _SettingsSheet(
            mode: _themeMode,
            customBg: _customBg,
            customText: _customText,
            fontScale: _fontScale,
            lineHeight: _lineHeight,
            letterSpacing: _letterSpacing,
            textAlign: _textAlign,
          ),
    );

    if (picked == null || !mounted) return;

    // theme
    if (picked.mode == ReaderThemeMode.custom) {
      final bg = picked.customBg ?? (_customBg ?? const Color(0xFFF0F0F0));
      final tx = picked.customText ?? (_customText ?? Colors.black87);
      // ignore: deprecated_member_use
      await ReaderPrefs.setCustomColors(bg: bg.value, text: tx.value);
      await ReaderPrefs.setThemeMode(ReaderThemeMode.custom);
      setState(() {
        _themeMode = ReaderThemeMode.custom;
        _customBg = bg;
        _customText = tx;
      });
    } else {
      await ReaderPrefs.setThemeMode(picked.mode);
      setState(() => _themeMode = picked.mode);
    }

    // typography
    setState(() {
      _fontScale = picked.fontScale ?? _fontScale;
      _lineHeight = picked.lineHeight ?? _lineHeight;
      _letterSpacing = picked.letterSpacing ?? _letterSpacing;
      _textAlign = picked.textAlign ?? _textAlign;
    });
    await _persistTypography();
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
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
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
          // Chapter progress % (within) — only if enabled
          if (widget.showProgressUI)
            ValueListenableBuilder(
              valueListenable: ctrl.currentValueListenable,
              builder: (context, _, __) {
                final v = ctrl.currentValueListenable.value as dynamic;
                final p = _chapterPercent(v);
                final pct = (p * 100.0).clamp(0.0, 100.0);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: TextStyle(color: c.text),
                    ),
                  ),
                );
              },
            ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune),
            onPressed: _openSettingsSheet,
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(child: EpubViewTableOfContents(controller: ctrl)),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (_) => _onAnyScroll(ctrl),
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(_fontScale)),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: c.text,
              height: _lineHeight,
              letterSpacing: _letterSpacing,
            ),
            textAlign: _textAlign,
            child: EpubView(
              controller: ctrl,
              onDocumentLoaded: (_) {},
              onChapterChanged: (value) {
                final v = value as dynamic;
                final tocLen =
                    _controller?.tableOfContentsListenable.value.length ?? 0;
                final i0 = _zeroBasedChapter(v, tocLen: tocLen);
                _persistChapter(i0);
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: _BottomBar(
        controller: ctrl,
        colors: c,
        showProgressUI: widget.showProgressUI, // 👈 pass flag down
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Builder(
        builder:
            (ctx) => FloatingActionButton.small(
              heroTag: 'tocFab',
              tooltip: 'Chapters',
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              child: const Icon(Icons.list_alt),
            ),
      ),
    );
  } // <-- closes build
} // <-- closes _EpubReaderPageState

/// ======================
///  Bottom Bar (TOC-aware)
/// ======================
class _BottomBar extends StatelessWidget {
  final EpubController controller;
  final _ReaderChromeColors colors;
  final bool showProgressUI; // 👈 NEW
  const _BottomBar({
    required this.controller,
    required this.colors,
    required this.showProgressUI,
  });

  int _zeroBasedChapter(dynamic v, {required int tocLen}) {
    final raw = ((v?.chapterNumber ?? 1) as num).toInt();
    return raw <= 0 ? 0 : (raw - 1).clamp(0, tocLen > 0 ? tocLen - 1 : 0);
  }

  void _goChapterDelta(int delta) {
    final toc = controller.tableOfContentsListenable.value;
    if (toc.isEmpty) return; // nothing to do

    final v = controller.currentValueListenable.value as dynamic;
    final curr0 = _zeroBasedChapter(v, tocLen: toc.length);
    final next = (curr0 + delta).clamp(0, toc.length - 1).toInt();
    if (next != curr0) controller.scrollTo(index: next);
  }

  double _overallPercent(dynamic v) {
    final tocLen = controller.tableOfContentsListenable.value.length;
    final within =
        ((v?.progress ?? 0) as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.0;
    if (tocLen <= 0) return within;
    final chapterIdx0 = _zeroBasedChapter(v, tocLen: tocLen);
    final base = chapterIdx0 / tocLen;
    return (base + within / tocLen).clamp(0.0, 1.0);
  }

  double _chapterPercent(dynamic v) {
    final p = ((v?.progress) as num?)?.toDouble();
    if (p != null) return p.clamp(0.0, 1.0);
    final tocLen = controller.tableOfContentsListenable.value.length;
    if (tocLen <= 0) return 0.0;
    final chapterIdx0 = _zeroBasedChapter(v, tocLen: tocLen);
    final overall = _overallPercent(v);
    final base = chapterIdx0 / tocLen;
    final nextBase = (chapterIdx0 + 1) / tocLen;
    final span = nextBase - base;
    if (span <= 0) return 0.0;
    return ((overall - base) / span).clamp(0.0, 1.0);
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
        child: ValueListenableBuilder(
          valueListenable: controller.currentValueListenable,
          builder: (context, _, __) {
            final v = controller.currentValueListenable.value as dynamic;

            final tocLen = controller.tableOfContentsListenable.value.length;
            final hasToc = tocLen > 0;

            final within = _chapterPercent(v);
            final chapterPct = (within * 100).toStringAsFixed(0);

            final overall = _overallPercent(v);
            final chapterIdx0 =
                hasToc ? _zeroBasedChapter(v, tocLen: tocLen) : 0;

            final title =
                (v?.chapter?.Title ?? '-')
                    .toString()
                    .replaceAll('\n', '')
                    .trim();

            // Enable/disable nav buttons based on TOC and position
            final canPrev = hasToc && chapterIdx0 > 0;
            final canNext = hasToc && chapterIdx0 < tocLen - 1;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress rows — only when enabled
                if (showProgressUI) ...[
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: within,
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
                          value: overall,
                          backgroundColor: colors.progressBg,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          hasToc
                              ? 'Ch ${chapterIdx0 + 1}/$tocLen · $title'
                              : title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  // When hidden, still show the chapter title line (no bars/%)
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          hasToc
                              ? 'Ch ${chapterIdx0 + 1}/$tocLen · $title'
                              : title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Navigation controls — always visible
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: canPrev ? () => _goChapterDelta(-1) : null,
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Previous'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: canNext ? () => _goChapterDelta(1) : null,
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Next'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// ======================
///  Chrome Colors
/// ======================
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

/// ======================
///  Settings + Theme UI
/// ======================

class _ThemePickResult {
  final ReaderThemeMode mode;
  final Color? customBg;
  final Color? customText;

  // typography
  final double? fontScale;
  final double? lineHeight;
  final double? letterSpacing;
  final TextAlign? textAlign;

  _ThemePickResult(
    this.mode, {
    this.customBg,
    this.customText,
    this.fontScale,
    this.lineHeight,
    this.letterSpacing,
    this.textAlign,
  });
}

class _SettingsSheet extends StatefulWidget {
  final ReaderThemeMode mode;
  final Color? customBg;
  final Color? customText;

  final double fontScale;
  final double lineHeight;
  final double letterSpacing;
  final TextAlign textAlign;

  const _SettingsSheet({
    required this.mode,
    this.customBg,
    this.customText,
    required this.fontScale,
    required this.lineHeight,
    required this.letterSpacing,
    required this.textAlign,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late ReaderThemeMode _mode;
  Color? _bg;
  Color? _tx;

  late double _fontScale;
  late double _lineHeight;
  late double _letterSpacing;
  late TextAlign _textAlign;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _bg = widget.customBg;
    _tx = widget.customText;

    _fontScale = widget.fontScale;
    _lineHeight = widget.lineHeight;
    _letterSpacing = widget.letterSpacing;
    _textAlign = widget.textAlign;
  }

  Widget _tile({
    required Widget leading,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      minLeadingWidth: 0,
      leading: leading,
      title: Text(title),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: onTap,
    );
  }

  void _finish() {
    Navigator.pop(
      context,
      _ThemePickResult(
        _mode,
        customBg: _bg,
        customText: _tx,
        fontScale: _fontScale,
        lineHeight: _lineHeight,
        letterSpacing: _letterSpacing,
        textAlign: _textAlign,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            Center(
              child: Text(
                'Reader settings',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),

            // Text size
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [Text('Text size'), Text('A-        A+')],
            ),
            Slider(
              value: _fontScale,
              min: 0.8,
              max: 1.6,
              onChanged: (v) => setState(() => _fontScale = v),
            ),
            const SizedBox(height: 8),

            // Line space
            const Text('Line space'),
            Slider(
              value: _lineHeight,
              min: 1.2,
              max: 2.0,
              onChanged: (v) => setState(() => _lineHeight = v),
            ),
            const SizedBox(height: 8),

            // “Word space” (letter spacing)
            const Text('Word space'),
            Slider(
              value: _letterSpacing,
              min: 0.0,
              max: 1.5,
              onChanged: (v) => setState(() => _letterSpacing = v),
            ),
            const SizedBox(height: 8),

            // Paragraph space (not supported)
            Opacity(
              opacity: 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Paragraph space (not supported)'),
                  Slider(value: 0.0, min: 0.0, max: 1.0, onChanged: null),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Alignment
            const Text('Text alignment'),
            const SizedBox(height: 8),
            Row(
              children: [
                _AlignBtn(
                  icon: Icons.format_align_left,
                  selected: _textAlign == TextAlign.left,
                  onTap: () => setState(() => _textAlign = TextAlign.left),
                ),
                const SizedBox(width: 10),
                _AlignBtn(
                  icon: Icons.format_align_center,
                  selected: _textAlign == TextAlign.center,
                  onTap: () => setState(() => _textAlign = TextAlign.center),
                ),
                const SizedBox(width: 10),
                _AlignBtn(
                  icon: Icons.format_align_justify,
                  selected: _textAlign == TextAlign.justify,
                  onTap: () => setState(() => _textAlign = TextAlign.justify),
                ),
                const SizedBox(width: 10),
                _AlignBtn(
                  icon: Icons.format_align_right,
                  selected: _textAlign == TextAlign.right,
                  onTap: () => setState(() => _textAlign = TextAlign.right),
                ),
              ],
            ),

            const Divider(height: 24),

            // Page themes
            const Text('Page themes'),
            _tile(
              leading: const _Swatch(colors: [Colors.white, Colors.black87]),
              title: 'White',
              selected: _mode == ReaderThemeMode.light,
              onTap: () => setState(() => _mode = ReaderThemeMode.light),
            ),
            _tile(
              leading: const _Swatch(
                colors: [Color(0xFFFFF7E6), Color(0xFF3F2F1E)],
              ),
              title: 'Sepia',
              selected: _mode == ReaderThemeMode.sepia,
              onTap: () => setState(() => _mode = ReaderThemeMode.sepia),
            ),
            _tile(
              leading: const _Swatch(
                colors: [Color(0xFF111111), Color(0xFFECECEC)],
              ),
              title: 'Night',
              selected: _mode == ReaderThemeMode.dark,
              onTap: () => setState(() => _mode = ReaderThemeMode.dark),
            ),
            ListTile(
              minLeadingWidth: 0,
              leading: _Swatch(
                colors: [_bg ?? const Color(0xFFF0F0F0), _tx ?? Colors.black87],
              ),
              title: const Text('Custom…'),
              trailing:
                  _mode == ReaderThemeMode.custom
                      ? const Icon(Icons.check)
                      : const Icon(Icons.chevron_right),
              onTap: () async {
                final res = await showModalBottomSheet<_ThemePickResult>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder:
                      (_) => _CustomThemeSheet(
                        initialBg: _bg ?? const Color(0xFFF0F0F0),
                        initialText: _tx ?? Colors.black87,
                      ),
                );
                if (!mounted) return;
                if (res != null) {
                  setState(() {
                    _mode = ReaderThemeMode.custom;
                    _bg = res.customBg;
                    _tx = res.customText;
                  });
                }
              },
            ),

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _finish,
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlignBtn extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _AlignBtn({
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: selected ? Colors.green : Colors.black26),
          backgroundColor:
              selected
                  ? Colors.green.withValues(alpha: .08)
                  : Colors.transparent,
        ),
        child: Icon(icon),
      ),
    );
  }
}

/// Custom theme picker (colors only), used from Settings sheet
class _CustomThemeSheet extends StatefulWidget {
  final Color initialBg;
  final Color initialText;
  const _CustomThemeSheet({required this.initialBg, required this.initialText});

  @override
  State<_CustomThemeSheet> createState() => _CustomThemeSheetState();
}

class _CustomThemeSheetState extends State<_CustomThemeSheet> {
  late Color _bg;
  late Color _tx;

  static const _bgChoices = <Color>[
    Color(0xFFFFFFFF),
    Color(0xFFF7F7F7),
    Color(0xFFFFF7E6),
    Color(0xFFEFF7EE),
    Color(0xFF111111),
  ];
  static const _txChoices = <Color>[
    Colors.black87,
    Color(0xFF3F2F1E),
    Color(0xFF1B4332),
    Colors.brown,
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _bg = widget.initialBg;
    _tx = widget.initialText;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Custom Theme',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _ColorGrid(
                label: 'Background',
                colors: _bgChoices,
                selected: _bg,
                onPick: (c) => setState(() => _bg = c),
              ),
              const SizedBox(height: 12),
              _ColorGrid(
                label: 'Text',
                colors: _txChoices,
                selected: _tx,
                onPick: (c) => setState(() => _tx = c),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x22000000)),
                ),
                child: Text(
                  'Aa Preview',
                  style: TextStyle(
                    color: _tx,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      _ThemePickResult(
                        ReaderThemeMode.custom,
                        customBg: _bg,
                        customText: _tx,
                      ),
                    );
                  },
                  child: const Text('Use this theme'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorGrid extends StatelessWidget {
  final String label;
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onPick;
  const _ColorGrid({
    required this.label,
    required this.colors,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in colors)
              InkWell(
                onTap: () => onPick(c),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color:
                          selected == c
                              ? const Color(0xFF4A6BFE)
                              : const Color(0x22000000),
                      width: selected == c ? 2 : 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  final List<Color> colors;
  const _Swatch({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 20,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(child: Container(color: colors.first)),
          Expanded(child: Container(color: colors.last)),
        ],
      ),
    );
  }
}
