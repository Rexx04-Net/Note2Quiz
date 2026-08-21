import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MindMapNode {
  final String title;
  final String icon;
  final String description;
  final List<MindMapNode> children;
  bool isExpanded;

  MindMapNode({
    required this.title,
    this.icon = '📌',
    this.description = '',
    List<MindMapNode>? children,
    this.isExpanded = true,
  }) : children = children ?? [];

  factory MindMapNode.fromJson(Map<String, dynamic> json) {
    var rawChildren = json['children'] as List<dynamic>? ?? [];
    List<MindMapNode> childNodes = rawChildren
        .map((c) => c is Map<String, dynamic> ? MindMapNode.fromJson(c) : MindMapNode(title: c.toString()))
        .toList();

    return MindMapNode(
      title: json['title'] ?? 'Topic',
      icon: json['icon'] ?? '📌',
      description: json['description'] ?? '',
      children: childNodes,
    );
  }

  static MindMapNode parseFromText(String rawText) {
    final lines = rawText.split('\n');
    MindMapNode root = MindMapNode(title: 'Mind Map', icon: '🧠', description: 'Interactive Concept Tree');
    
    MindMapNode? currentSection;

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('#') || trimmed.contains('🌟') || (trimmed.startsWith('Chapter') && !trimmed.contains(':'))) {
        final title = trimmed.replaceAll(RegExp(r'^[#*\s🌟➡️1-9.]+'), '').trim();
        if (title.isNotEmpty) {
          root = MindMapNode(title: title, icon: '🧠', description: 'Central Topic');
        }
      } else if (RegExp(r'^\d+\.\s*').hasMatch(trimmed) || trimmed.startsWith('➡️')) {
        final title = trimmed.replaceAll(RegExp(r'^\d+\.\s*|➡️'), '').trim();
        currentSection = MindMapNode(title: title, icon: '🎯', description: 'Main Category');
        root.children.add(currentSection);
      } else if (trimmed.startsWith('-') || trimmed.startsWith('*') || trimmed.startsWith('•')) {
        final itemText = trimmed.substring(1).trim();
        final childNode = MindMapNode(title: itemText, icon: '💡');
        if (currentSection != null) {
          currentSection.children.add(childNode);
        } else {
          root.children.add(childNode);
        }
      } else {
        if (root.children.isEmpty) {
          currentSection = MindMapNode(title: trimmed, icon: '📌');
          root.children.add(currentSection);
        } else if (currentSection != null) {
          currentSection.children.add(MindMapNode(title: trimmed, icon: '🔹'));
        }
      }
    }

    if (root.children.isEmpty) {
      root.children.add(MindMapNode(title: 'Overview', icon: '📖', description: rawText.substring(0, rawText.length > 100 ? 100 : rawText.length)));
    }

    return root;
  }
}

class InteractiveMindMapViewer extends StatefulWidget {
  final dynamic data;

  const InteractiveMindMapViewer({
    super.key,
    required this.data,
  });

  @override
  State<InteractiveMindMapViewer> createState() => _InteractiveMindMapViewerState();
}

class _InteractiveMindMapViewerState extends State<InteractiveMindMapViewer> {
  late MindMapNode _rootNode;
  List<MindMapNode> _breadcrumb = [];
  late MindMapNode _focusedNode;

  final List<Color> _nodeColors = [
    Colors.deepPurpleAccent,
    Colors.blueAccent,
    Colors.tealAccent,
    Colors.amberAccent,
    Colors.pinkAccent,
    Colors.cyanAccent,
  ];

  @override
  void initState() {
    super.initState();
    _initTree();
  }

  @override
  void didUpdateWidget(covariant InteractiveMindMapViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _initTree();
    }
  }

  void _initTree() {
    if (widget.data is Map<String, dynamic>) {
      _rootNode = MindMapNode.fromJson(widget.data as Map<String, dynamic>);
    } else if (widget.data is String) {
      final strData = widget.data.toString().trim();
      if (strData.startsWith('{') && strData.endsWith('}')) {
        try {
          final parsed = jsonDecode(strData);
          if (parsed is Map<String, dynamic>) {
            _rootNode = MindMapNode.fromJson(parsed);
          } else {
            _rootNode = MindMapNode.parseFromText(strData);
          }
        } catch (_) {
          _rootNode = MindMapNode.parseFromText(strData);
        }
      } else {
        _rootNode = MindMapNode.parseFromText(strData);
      }
    } else {
      _rootNode = MindMapNode(title: 'Mind Map', icon: '🧠');
    }

    _focusedNode = _rootNode;
    _breadcrumb = [_rootNode];
  }

  void _expandAll(MindMapNode node, bool expand) {
    setState(() {
      node.isExpanded = expand;
      for (var child in node.children) {
        _expandAll(child, expand);
      }
    });
  }

  void _drillDown(MindMapNode node) {
    setState(() {
      _focusedNode = node;
      _breadcrumb.add(node);
    });
  }

  void _navigateToBreadcrumb(int index) {
    setState(() {
      _focusedNode = _breadcrumb[index];
      _breadcrumb = _breadcrumb.sublist(0, index + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mind Map Header Controls
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_tree_rounded, color: scheme.primary, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Interactive Visual Mind Map',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Tooltip(
                    message: 'Expand All Nodes',
                    child: IconButton(
                      icon: const Icon(Icons.unfold_more, size: 20),
                      onPressed: () => _expandAll(_focusedNode, true),
                    ),
                  ),
                  Tooltip(
                    message: 'Collapse All Nodes',
                    child: IconButton(
                      icon: const Icon(Icons.unfold_less, size: 20),
                      onPressed: () => _expandAll(_focusedNode, false),
                    ),
                  ),
                  Tooltip(
                    message: 'Reset Focus to Root',
                    child: IconButton(
                      icon: const Icon(Icons.center_focus_strong, size: 20),
                      onPressed: () => _navigateToBreadcrumb(0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Breadcrumb Trail Navigation
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _breadcrumb.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final node = entry.value;
                    final isLast = idx == _breadcrumb.length - 1;

                    return Row(
                      children: [
                        InkWell(
                          onTap: () => _navigateToBreadcrumb(idx),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isLast ? scheme.primary.withOpacity(0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isLast ? scheme.primary : colors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(node.icon, style: const TextStyle(fontSize: 12)),
                                const SizedBox(width: 6),
                                Text(
                                  node.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isLast ? FontWeight.bold : FontWeight.w500,
                                    color: isLast ? scheme.primary : scheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!isLast)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Visual Tree Diagram Container
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.border),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Central Node Header
                  _buildRootNodeCard(_focusedNode, context),
                  const SizedBox(height: 24),
                  // Children Branches Layout
                  if (_focusedNode.children.isNotEmpty)
                    Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      alignment: WrapAlignment.center,
                      children: _focusedNode.children.asMap().entries.map((entry) {
                        final color = _nodeColors[entry.key % _nodeColors.length];
                        return _buildBranchCard(entry.value, color, context, depth: 1);
                      }).toList(),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'This is a terminal node with no sub-topics.',
                        style: TextStyle(color: colors.mutedText, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRootNodeCard(MindMapNode node, BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary.withOpacity(0.3),
            scheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.2),
            blurRadius: 16,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(node.icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  node.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          if (node.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              node.description,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurface.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${node.children.length} Sub-branches',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchCard(MindMapNode node, Color accentColor, BuildContext context, {int depth = 1}) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final hasChildren = node.children.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: depth == 1 ? 320 : double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withOpacity(0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branch Header Tile
          InkWell(
            onTap: () {
              if (hasChildren) {
                setState(() => node.isExpanded = !node.isExpanded);
              }
            },
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Text(node.icon, style: const TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface,
                          ),
                        ),
                        if (node.description.isNotEmpty)
                          Text(
                            node.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.mutedText,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (hasChildren) ...[
                    // Expand/Collapse Icon
                    IconButton(
                      icon: Icon(
                        node.isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: accentColor,
                      ),
                      onPressed: () {
                        setState(() => node.isExpanded = !node.isExpanded);
                      },
                    ),
                    // Focus / Drill-down Button
                    IconButton(
                      icon: Icon(Icons.fullscreen, color: accentColor, size: 20),
                      tooltip: 'Focus into sub-topic',
                      onPressed: () => _drillDown(node),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Collapsible Children Tree
          if (hasChildren && node.isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    height: 1.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accentColor.withOpacity(0.5), Colors.transparent],
                      ),
                    ),
                  ),
                  Column(
                    children: node.children.map((child) {
                      return _buildSubNodeItem(child, accentColor, context);
                    }).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubNodeItem(MindMapNode child, Color accentColor, BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasSubChildren = child.children.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(child.icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  child.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (hasSubChildren)
                InkWell(
                  onTap: () => _drillDown(child),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${child.children.length}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, size: 10, color: accentColor),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (child.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              child.description,
              style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
            ),
          ],
        ],
      ),
    );
  }
}
