import 'package:flutter/material.dart';

/// In-memory prefs for reader settings (swap with real storage later).
class _ReaderPrefs {
  static ReaderThemeMode _theme = ReaderThemeMode.light;
  static ReaderThemeMode get theme => _theme;
  static set theme(ReaderThemeMode v) => _theme = v;
}

enum ReaderThemeMode { light, dark, sepia }

/// Very small in-memory progress store (swap with shared_prefs/backend later).
class _ReadingProgress {
  static final Map<String, int> _lastChapterIndex = {};
  static int getChapter(String bookTitle) => _lastChapterIndex[bookTitle] ?? 0;
  static void setChapter(String bookTitle, int index) {
    _lastChapterIndex[bookTitle] = index;
  }
}

class ReaderPage extends StatefulWidget {
  final String bookTitle;
  final List<String> chapters;
  final int initialChapterIndex;

  const ReaderPage({
    super.key,
    required this.bookTitle,
    required this.chapters,
    this.initialChapterIndex = 0,
  });

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late int _chapterIndex;
  double _fontSize = 16;

  // NEW: theme + progress within current chapter
  ReaderThemeMode _themeMode = _ReaderPrefs.theme;
  final _scrollController = ScrollController();
  double _chapterScrollProgress = 0.0; // 0..1

  @override
  void initState() {
    super.initState();
    // Resume where the user left off if we have it; otherwise use the provided index.
    _chapterIndex = _ReadingProgress.getChapter(widget.bookTitle);
    if (_chapterIndex < 0 || _chapterIndex >= widget.chapters.length) {
      _chapterIndex = widget.initialChapterIndex;
    }

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    // Save last chapter on exit.
    _ReadingProgress.setChapter(widget.bookTitle, _chapterIndex);
    super.dispose();
  }

  void _onScroll() {
    final max = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset.clamp(0.0, max);
    final p = max > 0 ? (offset / max) : 0.0;
    if ((p - _chapterScrollProgress).abs() > 0.005) {
      setState(() => _chapterScrollProgress = p);
    }
  }

  void _goPrev() {
    if (_chapterIndex == 0) return;
    setState(() {
      _chapterIndex--;
      _chapterScrollProgress = 0.0;
      _scrollController.jumpTo(0);
    });
  }

  void _goNext() {
    if (_chapterIndex >= widget.chapters.length - 1) return;
    setState(() {
      _chapterIndex++;
      _chapterScrollProgress = 0.0;
      _scrollController.jumpTo(0);
    });
  }

  void _pickTheme() async {
    final picked = await showModalBottomSheet<ReaderThemeMode>(
      context: context,
      showDragHandle: true,
      // Keep defaults so Flutter gives the sheet sane constraints
      builder: (_) => _ThemeSheet(current: _themeMode),
    );
    if (picked != null) {
      setState(() {
        _themeMode = picked;
        _ReaderPrefs.theme = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapterName = widget.chapters[_chapterIndex];

    // THEME COLORS
    final colors = _themeColors(_themeMode);
    final textStyle = TextStyle(
      fontSize: _fontSize,
      height: 1.5,
      color: colors.text,
    );

    final chapterProgressPct = (_chapterScrollProgress * 100).clamp(0, 100);
    final overallProgress =
        (_chapterIndex + _chapterScrollProgress) / widget.chapters.length;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(chapterName, overflow: TextOverflow.ellipsis),
        actions: [
          // Chapter picker
          PopupMenuButton<int>(
            tooltip: 'Chapters',
            icon: const Icon(Icons.menu_book_outlined),
            onSelected:
                (i) => setState(() {
                  _chapterIndex = i;
                  _chapterScrollProgress = 0.0;
                  _scrollController.jumpTo(0);
                }),
            itemBuilder:
                (_) => [
                  for (var i = 0; i < widget.chapters.length; i++)
                    PopupMenuItem<int>(
                      value: i,
                      child: Row(
                        children: [
                          if (i == _chapterIndex)
                            const Icon(Icons.check, size: 16)
                          else
                            const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              widget.chapters[i],
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
          ),
          // Font size
          IconButton(
            tooltip: 'Text size',
            icon: const Icon(Icons.text_fields),
            onPressed: () async {
              final newSize = await showModalBottomSheet<double>(
                context: context,
                showDragHandle: true,
                builder: (_) => _FontSizeSheet(current: _fontSize),
              );
              if (newSize != null) setState(() => _fontSize = newSize);
            },
          ),
          // Theme
          IconButton(
            tooltip: 'Theme',
            icon: const Icon(Icons.palette_outlined),
            onPressed: _pickTheme,
          ),
        ],
      ),

      // Content area — mock paragraphs for now.
      body: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        itemCount: 22, // fake paragraphs per chapter
        itemBuilder: (_, i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SelectableText(
              _mockParagraph(chapterName, i),
              style: textStyle,
            ),
          );
        },
      ),

      // Controls + PROGRESS (lightweight)
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Chapter progress
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _chapterScrollProgress,
                      backgroundColor: colors.progressBg,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${chapterProgressPct.toStringAsFixed(0)}%',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Overall book progress
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: overallProgress,
                      backgroundColor: colors.progressBg,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ch ${_chapterIndex + 1}/${widget.chapters.length}',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _chapterIndex == 0 ? null : _goPrev,
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _chapterIndex >= widget.chapters.length - 1
                              ? null
                              : _goNext,
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Next'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tiny mock to simulate different content per chapter
  String _mockParagraph(String chapterName, int i) {
    return '$chapterName · Paragraph ${i + 1}\n'
        'This is placeholder reading text. Replace this widget with a real EPUB/PDF '
        'reader or API-delivered chapter content when your backend is ready. '
        'We keep it super light and selectable for now.';
  }

  // Map theme to actual colors
  _ReaderColors _themeColors(ReaderThemeMode mode) {
    switch (mode) {
      case ReaderThemeMode.dark:
        return _ReaderColors(
          background: const Color(0xFF111111),
          surface: const Color(0xFF1A1A1A),
          text: const Color(0xFFECECEC),
          textSecondary: const Color(0xFFBFBFBF),
          divider: const Color(0xFF2A2A2A),
          progressBg: const Color(0xFF2A2A2A),
        );
      case ReaderThemeMode.sepia:
        return _ReaderColors(
          background: const Color(0xFFFFF7E6),
          surface: const Color(0xFFFFF1D6),
          text: const Color(0xFF3F2F1E),
          textSecondary: const Color(0xFF7A6A55),
          divider: const Color(0xFFE8DABE),
          progressBg: const Color(0xFFEADFC8),
        );
      case ReaderThemeMode.light:
      default:
        return _ReaderColors(
          background: Colors.white,
          surface: Colors.white,
          text: Colors.black87,
          textSecondary: Colors.black54,
          divider: const Color(0x14000000),
          progressBg: const Color(0x11000000),
        );
    }
  }
}

class _ReaderColors {
  final Color background;
  final Color surface;
  final Color text;
  final Color textSecondary;
  final Color divider;
  final Color progressBg;
  _ReaderColors({
    required this.background,
    required this.surface,
    required this.text,
    required this.textSecondary,
    required this.divider,
    required this.progressBg,
  });
}

class _FontSizeSheet extends StatefulWidget {
  final double current;
  const _FontSizeSheet({required this.current});

  @override
  State<_FontSizeSheet> createState() => _FontSizeSheetState();
}

class _FontSizeSheetState extends State<_FontSizeSheet> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.current.clamp(12, 24);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Text size',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          Slider(
            value: _value,
            min: 12,
            max: 24,
            divisions: 12,
            label: _value.toStringAsFixed(0),
            onChanged: (v) => setState(() => _value = v),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _value),
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeSheet extends StatelessWidget {
  final ReaderThemeMode current;
  const _ThemeSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    Widget tile(ReaderThemeMode mode, String label, Widget swatch) {
      final selected = mode == current;
      return ListTile(
        leading: swatch,
        title: Text(label),
        trailing: selected ? const Icon(Icons.check) : null,
        onTap: () => Navigator.pop(context, mode),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min, // <-- key line
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'Theme',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            tile(
              ReaderThemeMode.light,
              'Light',
              const _Swatch(colors: [Colors.white, Colors.black87]),
            ),
            tile(
              ReaderThemeMode.sepia,
              'Sepia',
              const _Swatch(colors: [Color(0xFFFFF7E6), Color(0xFF3F2F1E)]),
            ),
            tile(
              ReaderThemeMode.dark,
              'Dark',
              const _Swatch(colors: [Color(0xFF111111), Color(0xFFECECEC)]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final List<Color> colors;
  const _Swatch({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min, // <-- ADD THIS LINE
      children: [
        for (final c in colors)
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0x22000000)),
            ),
          ),
      ],
    );
  }
}
