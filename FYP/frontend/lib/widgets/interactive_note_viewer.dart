import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

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
            Icon(Icons.check_circle, color: Colors.greenAccent),
            SizedBox(width: 10),
            Text('Note content copied to clipboard!'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    final parsedBlocks = _parseMarkdownToBlocks(widget.content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Interactive Control Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: colors.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              if (widget.title != null) ...[
                Icon(Icons.auto_awesome, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
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
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF)),
                      ),
                      SizedBox(width: 6),
                      Text(
                        '⚡ Live Streaming',
                        style: TextStyle(color: Color(0xFF6C63FF), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Font size controls
              IconButton(
                icon: const Icon(Icons.format_size, size: 18),
                tooltip: 'Cycle Font Size',
                onPressed: () {
                  setState(() {
                    if (_fontSize >= 19.0) {
                      _fontSize = 13.0;
                    } else {
                      _fontSize += 2.0;
                    }
                  });
                },
              ),
              // Search toggle
              IconButton(
                icon: Icon(_showSearch ? Icons.search_off : Icons.search, size: 18),
                tooltip: 'Search in Note',
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
                onPressed: () => _copyToClipboard(context),
              ),
            ],
          ),
        ),

        if (_showSearch)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search text...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),

        // Parsed Colorful Note Content
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: parsedBlocks.map((block) => _buildBlockWidget(block, context)).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlockWidget(_NoteBlock block, BuildContext context) {
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
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 18, bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.primary.withOpacity(0.18),
                scheme.surface,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: scheme.primary, width: 4),
            ),
          ),
          child: Text(
            block.text,
            style: TextStyle(
              fontSize: block.type == _BlockType.header1
                  ? _fontSize + 4
                  : block.type == _BlockType.header2
                      ? _fontSize + 2
                      : _fontSize + 1,
              fontWeight: FontWeight.bold,
              color: scheme.primary,
              letterSpacing: 0.4,
            ),
          ),
        );

      case _BlockType.keyValue:
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.secondary.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${block.key}: ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: _fontSize - 1,
                  color: scheme.secondary,
                ),
              ),
              Flexible(
                child: Text(
                  block.text,
                  style: TextStyle(
                    fontSize: _fontSize - 1,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );

      case _BlockType.bullet:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 7, right: 10),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.5),
                      blurRadius: 4,
                    )
                  ],
                ),
              ),
              Expanded(
                child: _buildRichText(block.text, context),
              ),
            ],
          ),
        );

      case _BlockType.divider:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 14),
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.primary.withOpacity(0.5),
                scheme.secondary.withOpacity(0.5),
                Colors.transparent,
              ],
            ),
          ),
        );

      case _BlockType.codeBlock:
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.primary.withOpacity(0.3)),
          ),
          child: Stack(
            children: [
              Text(
                block.text,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: _fontSize - 1,
                  color: scheme.primary,
                  height: 1.5,
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: block.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code snippet copied!')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.copy, size: 14, color: scheme.onSurface),
                  ),
                ),
              ),
            ],
          ),
        );

      case _BlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildRichText(block.text, context),
        );
    }
  }

  Widget _buildRichText(String text, BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    // Regex to capture **bold** and `code`
    final regex = RegExp(r'(\*\*(.*?)\*\*|`(.*?)`)');
    final matches = regex.allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: _fontSize,
          height: 1.65,
          color: scheme.onSurface.withOpacity(0.9),
        ),
      );
    }

    List<InlineSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: TextStyle(
              fontSize: _fontSize,
              height: 1.65,
              color: scheme.onSurface.withOpacity(0.9),
            ),
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
            style: TextStyle(
              fontSize: _fontSize,
              fontWeight: FontWeight.bold,
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
                border: Border.all(color: scheme.primary.withOpacity(0.3)),
              ),
              child: Text(
                codeContent,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: _fontSize - 1,
                  fontWeight: FontWeight.bold,
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
          style: TextStyle(
            fontSize: _fontSize,
            height: 1.65,
            color: scheme.onSurface.withOpacity(0.9),
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans),
    );
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

enum _BlockType { header1, header2, header3, keyValue, bullet, divider, codeBlock, paragraph }

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
