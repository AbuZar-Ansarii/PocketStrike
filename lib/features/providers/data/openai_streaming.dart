/// Accumulates OpenAI-style streamed `tool_calls` fragments.
library;

import '../../../core/models/chat_models.dart';

class ToolCallFragmentBuilder {
  String? id;
  String? name;
  final StringBuffer arguments = StringBuffer();

  void absorb(Map<String, dynamic> fragment) {
    if (fragment['id'] is String) id = fragment['id'] as String;
    final fn = fragment['function'] as Map<String, dynamic>?;
    if (fn != null) {
      if (fn['name'] is String) name = fn['name'] as String;
      if (fn['arguments'] is String) {
        arguments.write(fn['arguments'] as String);
      }
    }
  }

  ToolCallInfo? build(int index) {
    if (name == null) return null;
    return ToolCallInfo(
      id: id ?? 'call_$index',
      name: name!,
      argumentsJson: arguments.isEmpty ? '{}' : arguments.toString(),
    );
  }
}
