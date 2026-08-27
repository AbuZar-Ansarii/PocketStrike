import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pocketstrike/features/agent/domain/agent_tool.dart';

/// Built-in Device Hardware & System Tools (Clipboard, Device Specs, System Info).
class DeviceAgentTools {
  const DeviceAgentTools._();

  static List<AgentTool> all() => [
        getClipboard(),
        setClipboard(),
        getDeviceInfo(),
      ];

  static AgentTool getClipboard() => AgentTool(
        name: 'get_clipboard',
        description: 'Returns the current text content copied to the device clipboard.',
        inputSchema: const {
          'type': 'object',
          'properties': <String, dynamic>{},
        },
        risk: ToolRisk.safe,
        run: (args) async {
          try {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            final text = data?.text ?? '';
            if (text.isEmpty) return 'Clipboard is currently empty.';
            return 'Clipboard text: "$text"';
          } catch (e) {
            return 'Could not read clipboard: ${e.toString()}';
          }
        },
      );

  static AgentTool setClipboard() => AgentTool(
        name: 'set_clipboard',
        description: 'Copies a given text string to the device system clipboard.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'text': {
              'type': 'string',
              'description': 'The text string to copy to the clipboard.',
            },
          },
          'required': ['text'],
        },
        risk: ToolRisk.safe,
        run: (args) async {
          final text = args['text'] as String? ?? '';
          if (text.isEmpty) return 'Error: Text cannot be empty.';
          try {
            await Clipboard.setData(ClipboardData(text: text));
            return 'Successfully copied text to system clipboard ("$text").';
          } catch (e) {
            return 'Failed to set clipboard: ${e.toString()}';
          }
        },
      );

  static AgentTool getDeviceInfo() => AgentTool(
        name: 'get_device_info',
        description: 'Returns hardware and OS system specifications of the mobile device.',
        inputSchema: const {
          'type': 'object',
          'properties': <String, dynamic>{},
        },
        risk: ToolRisk.safe,
        run: (args) async {
          final os = Platform.operatingSystem;
          final version = Platform.operatingSystemVersion;
          final cores = Platform.numberOfProcessors;
          final hostname = Platform.localHostname;
          return 'Device Specifications:\n'
              '• OS: $os ($version)\n'
              '• CPU Cores: $cores\n'
              '• Hostname: $hostname';
        },
      );
}
