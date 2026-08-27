import 'dart:math' as math;

import '../domain/agent_tool.dart';
import 'android_automation_tools.dart';
import 'device_tools.dart';
import 'document_tools.dart';
import 'extra_agent_tools.dart';
import 'storage_tools.dart';

/// Safe built-in tools available to the agent out of the box.
class BuiltInTools {
  const BuiltInTools._();

  static List<AgentTool> all({List<String> allowedRoots = const []}) => [
        currentTime(),
        calculator(),
        ...DeviceAgentTools.all(),
        ...AndroidAutomationTools.all(),
        ...DocumentAgentTools.all(),
        ...StorageAgentTools.tools(allowedRoots: allowedRoots),
        ...ExtraAgentTools.all(),
      ];

  static AgentTool currentTime() => AgentTool(
        name: 'get_current_time',
        description:
            'Returns the current local date, time and timezone of the device.',
        inputSchema: const {
          'type': 'object',
          'properties': <String, dynamic>{},
        },
        risk: ToolRisk.safe,
        run: (args) async {
          final now = DateTime.now();
          return 'Current device time: ${now.toIso8601String()} '
              '(${now.timeZoneName})';
        },
      );

  static AgentTool calculator() => AgentTool(
        name: 'calculator',
        description:
            'Evaluates a basic arithmetic expression with + - * / % ^ '
            'and parentheses. Example: "(4 + 2) * 3.5".',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'expression': {
              'type': 'string',
              'description': 'The arithmetic expression to evaluate.',
            },
          },
          'required': ['expression'],
        },
        risk: ToolRisk.safe,
        run: (args) async {
          final expression = args['expression'] as String? ?? '';
          try {
            final result = _ExpressionParser(expression).parse();
            final formatted = result == result.roundToDouble()
                ? result.toStringAsFixed(0)
                : result.toString();
            return '$expression = $formatted';
          } on FormatException catch (e) {
            return 'Could not evaluate "$expression": ${e.message}';
          }
        },
      );
}

/// Tiny recursive-descent parser for safe arithmetic evaluation
/// (no `eval`, no dynamic code execution).
class _ExpressionParser {
  _ExpressionParser(this._input);

  final String _input;
  int _pos = 0;

  double parse() {
    final value = _parseExpr();
    _skipWs();
    if (_pos != _input.length) {
      throw FormatException('Unexpected character at position $_pos');
    }
    return value;
  }

  void _skipWs() {
    while (_pos < _input.length && _input[_pos] == ' ') {
      _pos++;
    }
  }

  bool _eat(String char) {
    _skipWs();
    if (_pos < _input.length && _input[_pos] == char) {
      _pos++;
      return true;
    }
    return false;
  }

  double _parseExpr() {
    var value = _parseTerm();
    while (true) {
      if (_eat('+')) {
        value += _parseTerm();
      } else if (_eat('-')) {
        value -= _parseTerm();
      } else {
        return value;
      }
    }
  }

  double _parseTerm() {
    var value = _parseFactor();
    while (true) {
      if (_eat('*')) {
        value *= _parseFactor();
      } else if (_eat('/')) {
        final divisor = _parseFactor();
        if (divisor == 0) {
          throw const FormatException('Division by zero');
        }
        value /= divisor;
      } else if (_eat('%')) {
        value %= _parseFactor();
      } else {
        return value;
      }
    }
  }

  double _parseFactor() {
    final base = _parseUnary();
    if (_eat('^')) {
      final exponent = _parseFactor(); // right-associative
      return math.pow(base, exponent).toDouble();
    }
    return base;
  }

  double _parseUnary() {
    if (_eat('-')) return -_parseUnary();
    if (_eat('+')) return _parseUnary();
    return _parsePrimary();
  }

  double _parsePrimary() {
    _skipWs();
    if (_eat('(')) {
      final value = _parseExpr();
      if (!_eat(')')) {
        throw const FormatException('Missing closing parenthesis');
      }
      return value;
    }
    return _parseNumber();
  }

  double _parseNumber() {
    _skipWs();
    final start = _pos;
    while (_pos < _input.length &&
        (RegExp(r'[0-9.]').hasMatch(_input[_pos]))) {
      _pos++;
    }
    if (start == _pos) {
      throw FormatException('Expected a number at position $_pos');
    }
    final value = double.tryParse(_input.substring(start, _pos));
    if (value == null) {
      throw FormatException('Invalid number at position $start');
    }
    return value;
  }
}
