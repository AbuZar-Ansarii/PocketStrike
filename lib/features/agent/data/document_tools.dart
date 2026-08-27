import 'dart:io';
import 'package:pocketstrike/features/agent/domain/agent_tool.dart';

/// Document Converter & Text Extraction Tools.
class DocumentAgentTools {
  const DocumentAgentTools._();

  static List<AgentTool> all() => [
        extractTextFromFile(),
        formatMarkdownDocument(),
      ];

  static AgentTool extractTextFromFile() => AgentTool(
        name: 'extract_text_from_file',
        description: 'Parses text, markdown, JSON, or code files and extracts clean structured content.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'filePath': {
              'type': 'string',
              'description': 'Path of file to parse (e.g. "Downloads/report.txt" or "Downloads/data.json").',
            },
          },
          'required': ['filePath'],
        },
        risk: ToolRisk.safe,
        run: (args) async {
          final pathStr = args['filePath'] as String? ?? '';
          if (pathStr.isEmpty) return 'Error: File path is empty.';
          var resolved = pathStr.trim();
          if (resolved.startsWith('Download/') || resolved.startsWith('Downloads/')) {
            resolved = resolved.replaceFirst(RegExp(r'^Downloads?/'), '/storage/emulated/0/Download/');
          }
          final file = File(resolved);
          if (!await file.exists()) {
            return 'Error: Document "$resolved" not found.';
          }
          final content = await file.readAsString();
          return 'Extracted Document (${content.length} characters):\n---\n$content';
        },
      );

  static AgentTool formatMarkdownDocument() => AgentTool(
        name: 'format_markdown_document',
        description: 'Formats raw text or structured notes into GitHub Flavored Markdown.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'title': {
              'type': 'string',
              'description': 'Document title header.',
            },
            'body': {
              'type': 'string',
              'description': 'Main document content.',
            },
          },
          'required': ['title', 'body'],
        },
        risk: ToolRisk.safe,
        run: (args) async {
          final title = args['title'] as String? ?? 'Document';
          final body = args['body'] as String? ?? '';
          return '# $title\n\n$body\n\n---\n*Formatted by PocketStrike Document Agent*';
        },
      );
}
