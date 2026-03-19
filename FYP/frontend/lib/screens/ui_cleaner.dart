import 'package:flutter/material.dart';

class FormattedText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const FormattedText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    // Basic Markdown stripper and formatter
    List<Widget> spans = [];
    
    // Split by newlines to handle line-by-line formatting
    final lines = text.split('\n');
    
    for (var line in lines) {
      String trimmed = line.trim();
      
      if (trimmed.isEmpty) {
        spans.add(const SizedBox(height: 10));
        continue;
      }

      // --- 1. Headers (lines starting with #) ---
      if (trimmed.startsWith('#')) {
        // Remove # and whitespace
        String clean = trimmed.replaceAll(RegExp(r'^#+\s*'), '');
        spans.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "📌 $clean", // Add an emoji pin for style
              style: const TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: Color(0xFF6C63FF)
              )
            ),
          )
        );
      } 
      // --- 2. Bullet Points (lines starting with * or -) ---
      else if (trimmed.startsWith('* ') || trimmed.startsWith('- ')) {
         String clean = trimmed.substring(1).trim();
         
         // Handle bolding inside bullets (e.g. * **Title**: Desc)
         if (clean.contains('**')) {
           clean = clean.replaceAll('**', ''); // Simple strip for now
         }

         spans.add(
           Padding(
             padding: const EdgeInsets.only(left: 10, bottom: 4),
             child: Row(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 const Text("• ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                 Expanded(child: Text(clean, style: const TextStyle(fontSize: 14, height: 1.5))),
               ],
             ),
           )
         );
      }
      // --- 3. Standard Text (Handle **bold** stripping) ---
      else {
        String clean = line;
        if (clean.contains('**')) {
          clean = clean.replaceAll('**', ''); // Remove asterisks
        }
        spans.add(Text(clean, style: style ?? const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87)));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: spans,
    );
  }
}