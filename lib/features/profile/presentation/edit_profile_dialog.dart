import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../auth/domain/auth_user.dart';

typedef SaveProfile = Future<void> Function(String displayName, String bio);

Future<void> showEditProfileDialog({
  required BuildContext context,
  required AuthUser user,
  required SaveProfile onSave,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _EditProfileDialog(user: user, onSave: onSave),
  );
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({
    required this.user,
    required this.onSave,
  });

  final AuthUser user;
  final SaveProfile onSave;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.displayName);
    _bioController = TextEditingController(text: widget.user.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSave(
        _nameController.text.trim(),
        _bioController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException
            ? error.message
            : 'تعذر حفظ التعديلات. حاول مرة ثانية.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('تعديل الملف الشخصي'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الظاهر',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return 'الاسم مطلوب';
                    if (text.length > 60) return 'الاسم طويل جداً';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bioController,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'النبذة',
                    hintText: 'اكتب نبذة قصيرة عنك',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().length > 160) {
                      return 'النبذة طويلة جداً';
                    }
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(color: colors.error),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
