import 'package:flutter/material.dart';

import '../data/server_endpoint.dart';

Future<Uri?> showServerSettingsDialog(
  BuildContext context, {
  required Uri serverUri,
}) {
  return showDialog<Uri>(
    context: context,
    builder: (context) => _ServerSettingsDialog(serverUri: serverUri),
  );
}

class _ServerSettingsDialog extends StatefulWidget {
  const _ServerSettingsDialog({required this.serverUri});

  final Uri serverUri;

  @override
  State<_ServerSettingsDialog> createState() => _ServerSettingsDialogState();
}

class _ServerSettingsDialogState extends State<_ServerSettingsDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.serverUri.toString());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Server'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'WebSocket URL',
              prefixIcon: Icon(Icons.link_rounded),
            ),
            validator: (value) {
              try {
                normalizeServerWebSocketUri(value ?? '');
              } on FormatException catch (exception) {
                return exception.message;
              }

              return null;
            },
            onFieldSubmitted: (_) => _save(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            controller.text = defaultServerWebSocketUri().toString();
          },
          child: const Text('Use local'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  void _save() {
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(normalizeServerWebSocketUri(controller.text));
  }
}
