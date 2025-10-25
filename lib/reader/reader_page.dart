import 'package:flutter/material.dart';
import 'package:book_hub/services/reader_prefs.dart';

// Persisted theme options

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

  // theme + within-chapter progress
  ReaderThemeMode _themeMode = ReaderThemeMode.light;
  Color? _customBg;
  Color? _customText;

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

    // load persisted prefs
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final mode = await ReaderPrefs.getThemeMode();
    final fs = await ReaderPrefs.getFontSize();

    Color? cBg, cTx;
    if (mode == ReaderThemeMode.custom) {
      final bg = await ReaderPrefs.getCustomBg();
      final tx = await ReaderPrefs.getCustomText();
      if (bg != null) cBg = Color(bg);
      if (tx != null) cTx = Color(tx);
    }

    if (!mounted) return;
    setState(() {
      _themeMode = mode;
      _fontSize = fs;
      _customBg = cBg;
      _customText = cTx;
    });
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
    if (!_scrollController.hasClients) return;
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

  Future<void> _pickTheme() async {
    final picked = await showModalBottomSheet<_ThemePickResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder:
          (_) => _ThemeSheet(
            current: _themeMode,
            currentCustomBg: _customBg,
            currentCustomText: _customText,
          ),
    );

    if (picked == null || !mounted) return;

    if (picked.mode == ReaderThemeMode.custom) {
      final bg = picked.customBg ?? Colors.white;
      final tx = picked.customText ?? Colors.black87;

      // For serialization, .value is the clearest way to get the 32-bit integer.
      // We ignore the deprecation warning because this is a valid use case.
      // ignore: deprecated_member_use
      final int bgValue = bg.value;
      // ignore: deprecated_member_use
      final int txValue = tx.value;

      await ReaderPrefs.setCustomColors(bg: bgValue, text: txValue);
      await ReaderPrefs.setThemeMode(ReaderThemeMode.custom);

      if (!mounted) return;
      setState(() {
        _themeMode = ReaderThemeMode.custom;
        _customBg = bg;
        _customText = tx;
      });
    } else {
      await ReaderPrefs.setThemeMode(picked.mode);
      if (!mounted) return;
      setState(() {
        _themeMode = picked.mode;
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
              if (newSize == null) return;

              if (!mounted) return; // ✅ guard State after async gap
              setState(() => _fontSize = newSize);

              // Persist (no context use here, so no extra guard needed)
              await ReaderPrefs.setFontSize(newSize);
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

  // Map theme to actual colors (includes custom)
  _ReaderColors _themeColors(ReaderThemeMode mode) {
    if (mode == ReaderThemeMode.custom &&
        _customBg != null &&
        _customText != null) {
      return _ReaderColors(
        background: _customBg!,
        surface: _customBg!,
        text: _customText!,
        textSecondary: _customText!.withAlpha(180),
        divider: const Color(0x22000000),
        progressBg: const Color(0x11000000),
      );
    }

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

class _ThemePickResult {
  final ReaderThemeMode mode;
  final Color? customBg;
  final Color? customText;
  _ThemePickResult(this.mode, {this.customBg, this.customText});
}

class _ThemeSheet extends StatefulWidget {
  final ReaderThemeMode current;
  final Color? currentCustomBg;
  final Color? currentCustomText;

  const _ThemeSheet({
    required this.current,
    this.currentCustomBg,
    this.currentCustomText,
  });

  @override
  State<_ThemeSheet> createState() => _ThemeSheetState();
}

class _ThemeSheetState extends State<_ThemeSheet> {
  @override
  Widget build(BuildContext context) {
    Widget tile({
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

    return Material(
      color:
          Theme.of(context).bottomSheetTheme.backgroundColor ??
          Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            const Center(
              child: Text(
                'Theme',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            tile(
              leading: const _Swatch(colors: [Colors.white, Colors.black87]),
              title: 'Light',
              selected: widget.current == ReaderThemeMode.light,
              onTap:
                  () => Navigator.pop(
                    context,
                    _ThemePickResult(ReaderThemeMode.light),
                  ),
            ),
            tile(
              leading: const _Swatch(
                colors: [Color(0xFFFFF7E6), Color(0xFF3F2F1E)],
              ),
              title: 'Sepia',
              selected: widget.current == ReaderThemeMode.sepia,
              onTap:
                  () => Navigator.pop(
                    context,
                    _ThemePickResult(ReaderThemeMode.sepia),
                  ),
            ),
            tile(
              leading: const _Swatch(
                colors: [Color(0xFF111111), Color(0xFFECECEC)],
              ),
              title: 'Dark',
              selected: widget.current == ReaderThemeMode.dark,
              onTap:
                  () => Navigator.pop(
                    context,
                    _ThemePickResult(ReaderThemeMode.dark),
                  ),
            ),
            const Divider(height: 24),
            // Custom…
            ListTile(
              minLeadingWidth: 0,
              leading: _Swatch(
                colors: [
                  widget.currentCustomBg ?? const Color(0xFFF0F0F0),
                  widget.currentCustomText ?? Colors.black87,
                ],
              ),
              title: const Text('Custom…'),
              subtitle: const Text('Pick background & text colors'),
              trailing:
                  widget.current == ReaderThemeMode.custom
                      ? const Icon(Icons.check)
                      : const Icon(Icons.chevron_right),
              onTap: () async {
                final res = await showModalBottomSheet<_ThemePickResult>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder:
                      (_) => _CustomThemeSheet(
                        initialBg:
                            widget.currentCustomBg ?? const Color(0xFFF0F0F0),
                        initialText: widget.currentCustomText ?? Colors.black87,
                      ),
                );

                // Guard the local BuildContext you’re about to use:
                if (!context.mounted) return;

                if (res != null) Navigator.pop(context, res);
              },
            ),
          ],
        ),
      ),
    );
  }
}

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

              // Preview chip
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
                      // Changed .value comparison to direct object comparison
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
    return Row(
      mainAxisSize:
          MainAxisSize.min, // avoids layout errors in ListTile.leading
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
