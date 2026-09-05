import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

enum NoteReadingTheme { system, sepia, midnight }

class InteractiveNoteViewer extends StatefulWidget {
  final String content;
  final String? title;
  final bool isStreaming;

  const InteractiveNoteViewer({
    super.key,
    required this.content,
    this.title,
    this.isStreaming = false,
  });

  @override
  State<InteractiveNoteViewer> createState() => _InteractiveNoteViewerState();
}

class _InteractiveNoteViewerState extends State<InteractiveNoteViewer> {
  double _fontSize = 15.0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;
  NoteReadingTheme _readingTheme = NoteReadingTheme.system;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
            SizedBox(width: 10),
            Text('Note content copied to clipboard!'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Color _getReaderBg(BuildContext context) {
    switch (_readingTheme) {
      case NoteReadingTheme.sepia:
        return const Color(0xFFFBF0D9);
      case NoteReadingTheme.midnight:
        return const Color(0xFF090D16);
      case NoteReadingTheme.system:
        return context.appColors.background;
    }
  }

  Color _getReaderText(BuildContext context) {
    switch (_readingTheme) {
      case NoteReadingTheme.sepia:
        return const Color(0xFF3F301D);
      case NoteReadingTheme.midnight:
        return const Color(0xFFE2E8F0);
      case NoteReadingTheme.system:
        return Theme.of(context).colorScheme.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final readerBg = _getReaderBg(context);
    final readerText = _getReaderText(context);

    final parsedBlocks = _parseMarkdownToBlocks(widget.content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Reader Control Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (widget.title != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.auto_awesome_rounded, size: 16, color: scheme.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title!,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (widget.isStreaming) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'AI Generating',
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
              ],

              // Font Size Adjustment Pills
              Container(
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Text('A-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      tooltip: 'Decrease font size',
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        if (_fontSize > 13.0) {
                          setState(() => _fontSize -= 1.5);
                        }
                      },
                    ),
                    Container(width: 1, height: 16, color: colors.border),
                    IconButton(
                      icon: const Text('A+', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      tooltip: 'Increase font size',
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        if (_fontSize < 22.0) {
                          setState(() => _fontSize += 1.5);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Reading Mode Switcher
              PopupMenuButton<NoteReadingTheme>(
                tooltip: 'Reading Tone',
                color: colors.surface,
                icon: Icon(
                  _readingTheme == NoteReadingTheme.sepia
                      ? Icons.wb_sunny_outlined
                      : _readingTheme == NoteReadingTheme.midnight
                          ? Icons.nights_stay_outlined
                          : Icons.palette_outlined,
                  size: 18,
                  color: colors.mutedText,
                ),
                onSelected: (theme) => setState(() => _readingTheme = theme),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: NoteReadingTheme.system,
                    child: Text('Default Theme'),
                  ),
                  const PopupMenuItem(
                    value: NoteReadingTheme.sepia,
                    child: Text('Warm Sepia (Day Reading)'),
                  ),
                  const PopupMenuItem(
                    value: NoteReadingTheme.midnight,
                    child: Text('Midnight (Ultra Dark)'),
                  ),
                ],
              ),

              // Search toggle
              IconButton(
                icon: Icon(_showSearch ? Icons.search_off_rounded : Icons.search_rounded, size: 18),
                tooltip: 'Search note',
                color: _showSearch ? scheme.primary : colors.mutedText,
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) _searchQuery = '';
                  });
                },
              ),

              // Copy Button
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copy Note',
                color: colors.mutedText,
                onPressed: () => _copyToClipboard(context),
              ),
            ],
          ),
        ),

        // Animated Search Field
        AnimatedCrossFade(
          crossFadeState: _showSearch ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Filter keywords in this note...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.border),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),
        ),

        // Centered Constrained Reading Canvas
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: readerBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.cardBorder),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: parsedBlocks.map((block) => _buildBlockWidget(block, context, readerText)).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlockWidget(_NoteBlock block, BuildContext context, Color readerText) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    // Filter check if searching
    if (_searchQuery.isNotEmpty && !block.text.toLowerCase().contains(_searchQuery)) {
      return const SizedBox.shrink();
    }

    switch (block.type) {
      case _BlockType.header1:
      case _BlockType.header2:
      case _BlockType.header3:
        final isH1 = block.type == _BlockType.header1;
        final isH2 = block.type == _BlockType.header2;
        return Container(
          width: double.infinity,
          margin: EdgeInsets.only(top: isH1 ? 28 : (isH2 ? 22 : 16), bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: isH1 ? 0.08 : 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: scheme.primary, width: isH1 ? 4 : 3),
            ),
          ),
          child: Text(
            block.text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isH1 ? _fontSize + 5 : (isH2 ? _fontSize + 3 : _fontSize + 1),
              fontWeight: FontWeight.w700,
              color: scheme.primary,
              letterSpacing: -0.2,
            ),
          ),
        );

      case _BlockType.callout:
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.primarySoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lightbulb_outline_rounded, color: scheme.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KEY TAKEAWAY',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildRichText(block.text, context, readerText),
                  ],
                ),
              ),
            ],
          ),
        );

      case _BlockType.keyValue:
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${block.key}: ',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: _fontSize - 0.5,
                  color: scheme.primary,
                ),
              ),
              Flexible(
                child: Text(
                  block.text,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: _fontSize - 0.5,
                    fontWeight: FontWeight.w500,
                    color: readerText,
                  ),
                ),
              ),
            ],
          ),
        );

      case _BlockType.bullet:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, right: 12),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: _buildRichText(block.text, context, readerText),
              ),
            ],
          ),
        );

      case _BlockType.divider:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Divider(color: colors.border, thickness: 1),
        );

      case _BlockType.codeBlock:
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Stack(
            children: [
              SelectableText(
                block.text,
                style: GoogleFonts.firaCode(
                  fontSize: _fontSize - 1,
                  color: scheme.primary,
                  height: 1.55,
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: block.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code snippet copied!')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: Icon(Icons.copy_rounded, size: 14, color: colors.mutedText),
                  ),
                ),
              ),
            ],
          ),
        );

      case _BlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _buildRichText(block.text, context, readerText),
        );
    }
  }

  Widget _buildRichText(String text, BuildContext context, Color readerText) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    // Regex to capture **bold** and `code`
    final regex = RegExp(r'(\*\*(.*?)\*\*|`(.*?)`)');
    final matches = regex.allMatches(text);

    final baseStyle = GoogleFonts.plusJakartaSans(
      fontSize: _fontSize,
      height: 1.68,
      letterSpacing: 0.15,
      color: readerText.withValues(alpha: 0.92),
    );

    if (matches.isEmpty) {
      return Text(text, style: baseStyle);
    }

    List<InlineSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: baseStyle,
          ),
        );
      }

      final matchText = match.group(0)!;
      if (matchText.startsWith('**') && matchText.endsWith('**')) {
        // Bold match
        final boldContent = matchText.substring(2, matchText.length - 2);
        spans.add(
          TextSpan(
            text: boldContent,
            style: baseStyle.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
        );
      } else if (matchText.startsWith('`') && matchText.endsWith('`')) {
        // Inline code match
        final codeContent = matchText.substring(1, matchText.length - 1);
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                codeContent,
                style: GoogleFonts.firaCode(
                  fontSize: _fontSize - 1.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ),
          ),
        );
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastMatchEnd),
          style: baseStyle,
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  List<_NoteBlock> _parseMarkdownToBlocks(String rawText) {
    final lines = rawText.split('\n');
    List<_NoteBlock> blocks = [];
    bool insideCodeFence = false;
    StringBuffer codeBuffer = StringBuffer();

    for (var line in lines) {
      final trimmed = line.trim();

      if (trimmed.startsWith('```')) {
        if (insideCodeFence) {
          blocks.add(_NoteBlock(type: _BlockType.codeBlock, text: codeBuffer.toString().trim()));
          codeBuffer.clear();
          insideCodeFence = false;
        } else {
          insideCodeFence = true;
        }
        continue;
      }

      if (insideCodeFence) {
        codeBuffer.writeln(line);
        continue;
      }

      if (trimmed.isEmpty) continue;

      // Divider `---` or `***`
      if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
        blocks.add(_NoteBlock(type: _BlockType.divider, text: ''));
        continue;
      }

      // Headers `#`, `##`, `###`
      if (trimmed.startsWith('# ')) {
        final title = trimmed.substring(2).trim();
        blocks.add(_NoteBlock(type: _BlockType.header1, text: title));
      } else if (trimmed.startsWith('## ')) {
        final title = trimmed.substring(3).trim();
        blocks.add(_NoteBlock(type: _BlockType.header2, text: title));
      } else if (trimmed.startsWith('### ')) {
        final title = trimmed.substring(4).trim();
        blocks.add(_NoteBlock(type: _BlockType.header3, text: title));
      }
      // Callout quotes `> ` or takeaway emojis
      else if (trimmed.startsWith('> ') ||
          trimmed.startsWith('💡') ||
          trimmed.toLowerCase().startsWith('key takeaway:') ||
          trimmed.toLowerCase().startsWith('summary:')) {
        String cleanText = trimmed;
        if (cleanText.startsWith('> ')) cleanText = cleanText.substring(2).trim();
        blocks.add(_NoteBlock(type: _BlockType.callout, text: cleanText));
      }
      // Key-Value pair e.g. **Date:** October 26, 2023
      else if (RegExp(r'^\*\*(.*?)\*\*:\s*(.*)').hasMatch(trimmed)) {
        final match = RegExp(r'^\*\*(.*?)\*\*:\s*(.*)').firstMatch(trimmed);
        if (match != null) {
          blocks.add(_NoteBlock(
            type: _BlockType.keyValue,
            key: match.group(1),
            text: match.group(2) ?? '',
          ));
        }
      }
      // Bullet items `- `, `* `, `• `
      else if (trimmed.startsWith('- ') || trimmed.startsWith('* ') || trimmed.startsWith('• ')) {
        final itemText = trimmed.substring(2).trim();
        blocks.add(_NoteBlock(type: _BlockType.bullet, text: itemText));
      }
      // Standard paragraph
      else {
        blocks.add(_NoteBlock(type: _BlockType.paragraph, text: trimmed));
      }
    }

    if (insideCodeFence && codeBuffer.isNotEmpty) {
      blocks.add(_NoteBlock(type: _BlockType.codeBlock, text: codeBuffer.toString().trim()));
    }

    return blocks;
  }
}

enum _BlockType { header1, header2, header3, callout, keyValue, bullet, divider, codeBlock, paragraph }

class _NoteBlock {
  final _BlockType type;
  final String text;
  final String? key;

  _NoteBlock({
    required this.type,
    required this.text,
    this.key,
  });
}
