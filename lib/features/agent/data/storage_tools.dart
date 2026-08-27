import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:pocketstrike/features/agent/domain/agent_tool.dart';

/// Sandboxed storage tools for agent file system operations on mobile devices.
class StorageAgentTools {
  const StorageAgentTools._();

  static List<AgentTool> tools({required List<String> allowedRoots}) {
    return [
      listFiles(allowedRoots),
      readFile(allowedRoots),
      writeFile(allowedRoots),
      createFolder(allowedRoots),
      deleteFile(allowedRoots),
      moveFile(allowedRoots),
      batchMoveFiles(allowedRoots),
      organizeDirectory(allowedRoots),
      searchFiles(allowedRoots),
    ];
  }

  /// Intelligent path resolver for mobile storage (e.g. Android /storage/emulated/0/Download).
  static String _resolvePath(String rawPath) {
    var pathStr = rawPath.trim();
    if (pathStr.isEmpty || pathStr == '.' || pathStr == 'Download' || pathStr == 'Downloads' || pathStr == 'downloads') {
      return '/storage/emulated/0/Download';
    }
    if (pathStr == 'Documents' || pathStr == 'documents') {
      return '/storage/emulated/0/Documents';
    }
    if (pathStr.startsWith('~/')) {
      return pathStr.replaceFirst('~/', '/storage/emulated/0/');
    }
    if (pathStr.startsWith('Download/') || pathStr.startsWith('Downloads/')) {
      return pathStr.replaceFirst(RegExp(r'^Downloads?/'), '/storage/emulated/0/Download/');
    }
    if (pathStr.startsWith('Documents/')) {
      return pathStr.replaceFirst('Documents/', '/storage/emulated/0/Documents/');
    }
    return pathStr;
  }

  static bool _isAllowed(String targetPath, List<String> allowedRoots) {
    if (allowedRoots.isEmpty) return true; // Default fallback to system access
    final normalizedTarget = p.canonicalize(targetPath);
    for (final root in allowedRoots) {
      final normalizedRoot = p.canonicalize(root);
      if (normalizedTarget == normalizedRoot ||
          p.isWithin(normalizedRoot, normalizedTarget)) {
        return true;
      }
    }
    return false;
  }

  static AgentTool listFiles(List<String> allowedRoots) => AgentTool(
        name: 'list_files',
        description:
            'Lists files and directories at the specified path (e.g. "/storage/emulated/0/Download" or "Downloads").',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'path': {
              'type': 'string',
              'description': 'Directory path to list (e.g. "Downloads" or "/storage/emulated/0/Download").',
            },
          },
          'required': ['path'],
        },
        risk: ToolRisk.safe,
        run: (args) async {
          final rawPath = args['path'] as String? ?? 'Downloads';
          final path = _resolvePath(rawPath);

          if (!_isAllowed(path, allowedRoots)) {
            return 'Error: Access denied. Path "$path" is outside allowed root folders.';
          }
          final dir = Directory(path);
          if (!await dir.exists()) {
            return 'Directory "$path" does not exist.';
          }
          final entries = await dir.list().toList();
          if (entries.isEmpty) return 'Directory "$path" is empty.';
          final buffer = StringBuffer('Contents of $path:\n');
          for (final entry in entries) {
            final isDir = entry is Directory;
            final name = p.basename(entry.path);
            buffer.writeln('${isDir ? "[DIR] " : "[FILE]"} $name');
          }
          return buffer.toString().trim();
        },
      );

  static AgentTool readFile(List<String> allowedRoots) => AgentTool(
        name: 'read_file',
        description:
            'Reads text content from a file at the specified path (e.g. "Downloads/notes.txt").',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'path': {
              'type': 'string',
              'description': 'File path to read.',
            },
          },
          'required': ['path'],
        },
        risk: ToolRisk.safe,
        run: (args) async {
          final rawPath = args['path'] as String? ?? '';
          final path = _resolvePath(rawPath);

          if (!_isAllowed(path, allowedRoots)) {
            return 'Error: Access denied. Path "$path" is outside allowed root folders.';
          }
          final file = File(path);
          if (!await file.exists()) {
            return 'Error: File "$path" does not exist.';
          }
          final content = await file.readAsString();
          return content;
        },
      );

  static AgentTool writeFile(List<String> allowedRoots) => AgentTool(
        name: 'write_file',
        description:
            'Writes or overwrites text content to a file at the specified path (e.g. "Downloads/joke.txt"). Creates file if missing.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'path': {
              'type': 'string',
              'description': 'File path to write to (e.g. "Downloads/joke.txt").',
            },
            'content': {
              'type': 'string',
              'description': 'Text content to write.',
            },
          },
          'required': ['path', 'content'],
        },
        risk: ToolRisk.safe,
        run: (args) async {
          final rawPath = args['path'] as String? ?? '';
          final path = _resolvePath(rawPath);
          final content = args['content'] as String? ?? '';

          if (!_isAllowed(path, allowedRoots)) {
            return 'Error: Access denied. Path "$path" is outside allowed root folders.';
          }
          final file = File(path);
          await file.parent.create(recursive: true);
          await file.writeAsString(content);
          return 'Successfully wrote ${content.length} characters to "$path".';
        },
      );

  static AgentTool createFolder(List<String> allowedRoots) => AgentTool(
        name: 'create_folder',
        description: 'Creates a new directory folder at the specified path.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'path': {
              'type': 'string',
              'description': 'Directory path to create (e.g. "Downloads/MyFolder").',
            },
          },
          'required': ['path'],
        },
        risk: ToolRisk.safe,
        run: (args) async {
          final rawPath = args['path'] as String? ?? '';
          final path = _resolvePath(rawPath);

          if (!_isAllowed(path, allowedRoots)) {
            return 'Error: Access denied. Path "$path" is outside allowed root folders.';
          }
          final dir = Directory(path);
          await dir.create(recursive: true);
          return 'Successfully created folder "$path".';
        },
      );

  static AgentTool deleteFile(List<String> allowedRoots) => AgentTool(
        name: 'delete_file',
        description:
            'Deletes a file or directory at the specified path.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'path': {
              'type': 'string',
              'description': 'File or directory path to delete.',
            },
          },
          'required': ['path'],
        },
        risk: ToolRisk.destructive,
        run: (args) async {
          final rawPath = args['path'] as String? ?? '';
          final path = _resolvePath(rawPath);

          if (!_isAllowed(path, allowedRoots)) {
            return 'Error: Access denied. Path "$path" is outside allowed root folders.';
          }
          final type = await FileSystemEntity.type(path);
          if (type == FileSystemEntityType.notFound) {
            return 'Path "$path" does not exist.';
          }
          if (type == FileSystemEntityType.directory) {
            await Directory(path).delete(recursive: true);
          } else {
            await File(path).delete();
          }
          return 'Successfully deleted "$path".';
        },
      );

  static AgentTool moveFile(List<String> allowedRoots) => AgentTool(
        name: 'move_file',
        description: 'Moves or renames a file/directory from source to destination.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'sourcePath': {
              'type': 'string',
              'description': 'Original path.',
            },
            'destinationPath': {
              'type': 'string',
              'description': 'New path.',
            },
          },
          'required': ['sourcePath', 'destinationPath'],
        },
        risk: ToolRisk.safe,
        run: (args) async {
          final src = _resolvePath(args['sourcePath'] as String? ?? '');
          final dst = _resolvePath(args['destinationPath'] as String? ?? '');
          if (!_isAllowed(src, allowedRoots) || !_isAllowed(dst, allowedRoots)) {
            return 'Error: Access denied. Both source and destination must be inside allowed root folders.';
          }
          final type = await FileSystemEntity.type(src);
          if (type == FileSystemEntityType.notFound) {
            return 'Source path "$src" does not exist.';
          }
          try {
            if (type == FileSystemEntityType.directory) {
              await Directory(dst).parent.create(recursive: true);
              await Directory(src).rename(dst);
            } else {
              final file = File(src);
              await File(dst).parent.create(recursive: true);
              try {
                await file.rename(dst);
              } catch (_) {
                // Fallback for cross-device partitions or permission boundaries
                await file.copy(dst);
                await file.delete();
              }
            }
            return 'Successfully moved "$src" to "$dst".';
          } catch (e) {
            return 'Failed to move "$src" to "$dst": $e';
          }
        },
      );

  static AgentTool batchMoveFiles(List<String> allowedRoots) => AgentTool(
        name: 'batch_move_files',
        description:
            'Moves multiple files or organizes a list of files into target directories in a single operation. '
            'Each item must specify "sourcePath" and "destinationPath".',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'moves': {
              'type': 'array',
              'description': 'List of move operations with sourcePath and destinationPath.',
              'items': {
                'type': 'object',
                'properties': {
                  'sourcePath': {'type': 'string'},
                  'destinationPath': {'type': 'string'},
                },
                'required': ['sourcePath', 'destinationPath'],
              },
            },
          },
          'required': ['moves'],
        },
        risk: ToolRisk.safe,
        run: (args) async {
          final movesRaw = args['moves'];
          if (movesRaw is! List || movesRaw.isEmpty) {
            return 'Error: "moves" list must contain at least one operation.';
          }
          var movedCount = 0;
          final errors = <String>[];

          for (final item in movesRaw) {
            if (item is! Map) continue;
            final src = _resolvePath(item['sourcePath'] as String? ?? '');
            final dst = _resolvePath(item['destinationPath'] as String? ?? '');
            if (!_isAllowed(src, allowedRoots) || !_isAllowed(dst, allowedRoots)) {
              errors.add('Access denied for $src -> $dst');
              continue;
            }
            try {
              final type = await FileSystemEntity.type(src);
              if (type == FileSystemEntityType.notFound) {
                errors.add('Not found: $src');
                continue;
              }
              if (type == FileSystemEntityType.directory) {
                await Directory(dst).parent.create(recursive: true);
                await Directory(src).rename(dst);
              } else {
                final file = File(src);
                await File(dst).parent.create(recursive: true);
                try {
                  await file.rename(dst);
                } catch (_) {
                  await file.copy(dst);
                  await file.delete();
                }
              }
              movedCount++;
            } catch (e) {
              errors.add('Error moving $src: $e');
            }
          }

          final buffer = StringBuffer('Successfully moved $movedCount file(s).');
          if (errors.isNotEmpty) {
            buffer.write('\nWarnings/Errors:\n• ${errors.join("\n• ")}');
          }
          return buffer.toString();
        },
      );

  static AgentTool organizeDirectory(List<String> allowedRoots) => AgentTool(
        name: 'organize_directory',
        description:
            'Automatically organizes and sorts all files in a directory into categorized subfolders '
            '(Documents, Images, Audio, Videos, Archives, Code, Others) based on file extensions.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'directory': {
              'type': 'string',
              'description': 'Directory path to organize (e.g. "Downloads" or "/storage/emulated/0/Download").',
            },
          },
          'required': ['directory'],
        },
        risk: ToolRisk.safe,
        run: (args) async {
          final rawPath = args['directory'] as String? ?? 'Downloads';
          final dirPath = _resolvePath(rawPath);

          if (!_isAllowed(dirPath, allowedRoots)) {
            return 'Error: Access denied. Path "$dirPath" is outside allowed root folders.';
          }
          final dir = Directory(dirPath);
          if (!await dir.exists()) return 'Directory "$dirPath" does not exist.';

          const extensionsToFolder = <String, String>{
            // Documents
            '.pdf': 'Documents',
            '.doc': 'Documents',
            '.docx': 'Documents',
            '.txt': 'Documents',
            '.xlsx': 'Documents',
            '.csv': 'Documents',
            '.pptx': 'Documents',
            '.epub': 'Documents',
            // Images
            '.jpg': 'Images',
            '.jpeg': 'Images',
            '.png': 'Images',
            '.gif': 'Images',
            '.webp': 'Images',
            '.svg': 'Images',
            // Media
            '.mp3': 'Audio',
            '.m4a': 'Audio',
            '.wav': 'Audio',
            '.mp4': 'Videos',
            '.mkv': 'Videos',
            '.mov': 'Videos',
            // Archives & Installers
            '.zip': 'Archives',
            '.rar': 'Archives',
            '.7z': 'Archives',
            '.tar': 'Archives',
            '.gz': 'Archives',
            '.apk': 'APKs',
            // Code & Data
            '.dart': 'Code',
            '.py': 'Code',
            '.js': 'Code',
            '.json': 'Code',
            '.html': 'Code',
          };

          var moved = 0;
          final categoriesUsed = <String>{};
          final entries = await dir.list().toList();

          for (final entity in entries) {
            if (entity is! File) continue;
            final ext = p.extension(entity.path).toLowerCase();
            final category = extensionsToFolder[ext] ?? 'Others';
            final targetDir = p.join(dirPath, category);
            final targetPath = p.join(targetDir, p.basename(entity.path));

            try {
              await Directory(targetDir).create(recursive: true);
              try {
                await entity.rename(targetPath);
              } catch (_) {
                await entity.copy(targetPath);
                await entity.delete();
              }
              moved++;
              categoriesUsed.add(category);
            } catch (_) {}
          }

          if (moved == 0) return 'No unorganized files found in "$dirPath".';
          return 'Successfully organized $moved file(s) into subfolders: ${categoriesUsed.join(", ")}.';
        },
      );

  static AgentTool searchFiles(List<String> allowedRoots) => AgentTool(
        name: 'search_files',
        description: 'Searches for files matching a pattern inside a directory.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'directory': {
              'type': 'string',
              'description': 'Root directory to search (e.g. "Downloads").',
            },
            'query': {
              'type': 'string',
              'description': 'Filename substring or extension to match.',
            },
          },
          'required': ['directory', 'query'],
        },
        risk: ToolRisk.safe,
        run: (args) async {
          final rawPath = args['directory'] as String? ?? 'Downloads';
          final dirPath = _resolvePath(rawPath);
          final query = (args['query'] as String? ?? '').toLowerCase();

          if (!_isAllowed(dirPath, allowedRoots)) {
            return 'Error: Access denied. Path "$dirPath" is outside allowed root folders.';
          }
          final dir = Directory(dirPath);
          if (!await dir.exists()) return 'Directory "$dirPath" does not exist.';
          final matches = <String>[];
          await for (final entity in dir.list(recursive: true)) {
            final name = p.basename(entity.path);
            if (name.toLowerCase().contains(query)) {
              matches.add(entity.path);
            }
          }
          if (matches.isEmpty) return 'No files matched "$query" in "$dirPath".';
          return 'Found ${matches.length} matching files:\n${matches.join("\n")}';
        },
      );
}
