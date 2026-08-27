import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/core/db/app_database.dart' show Persona;
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/features/conversations/application/conversations_controller.dart';

class PersonaEditDialog extends ConsumerStatefulWidget {
  const PersonaEditDialog({super.key, this.persona});

  final Persona? persona;

  static Future<void> show(BuildContext context, {Persona? persona}) {
    return showDialog(
      context: context,
      builder: (_) => PersonaEditDialog(persona: persona),
    );
  }

  @override
  ConsumerState<PersonaEditDialog> createState() => _PersonaEditDialogState();
}

class _PersonaEditDialogState extends ConsumerState<PersonaEditDialog> {
  final _nameController = TextEditingController();
  final _iconController = TextEditingController();
  final _promptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.persona != null) {
      _nameController.text = widget.persona!.name;
      _iconController.text = widget.persona!.icon;
      _promptController.text = widget.persona!.systemPrompt;
    } else {
      _iconController.text = '🤖';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _iconController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final prompt = _promptController.text.trim();
    if (name.isEmpty || prompt.isEmpty) return;

    await ref.read(personaActionsProvider).save(
          id: widget.persona?.id,
          name: name,
          systemPrompt: prompt,
          icon: _iconController.text.trim().isEmpty
              ? '🤖'
              : _iconController.text.trim(),
        );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.persona == null ? 'New Persona' : 'Edit Persona'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: _iconController,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'Icon',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Persona Name',
                      hintText: 'e.g. Python Expert',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _promptController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'System Prompt Instructions',
                hintText: 'You are an expert Python engineer...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(AppIcons.save, size: 16),
          label: const Text('Save'),
          onPressed: _save,
        ),
      ],
    );
  }
}
