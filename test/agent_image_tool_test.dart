import 'package:flutter_test/flutter_test.dart';
import 'package:pocketstrike/features/agent/data/extra_agent_tools.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ExtraAgentTools includes generate_image tool locked to 1:1 ratio', () {
    final tools = ExtraAgentTools.all();
    final imageTool = tools.where((t) => t.name == 'generate_image').firstOrNull;

    expect(imageTool, isNotNull);
    expect(imageTool!.description, contains('1:1'));
    expect(imageTool.inputSchema['properties'], contains('prompt'));
  });
}
