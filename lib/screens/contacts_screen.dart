import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import '../models/emergency_contact.dart';
import '../services/sms_service.dart';
import '../services/sos_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';

/// Strips formatting so numbers dial and text reliably. Returns null if what's
/// left can't be a phone number.
String? cleanPhoneNumber(String input) {
  final trimmed = input.trim();
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 7 || digits.length > 15) return null;
  return trimmed.startsWith('+') ? '+$digits' : digits;
}

/// True when two numbers reach the same phone, however they're written:
/// +91 98000 00001 and 098000 00001 differ only in their prefix.
bool isSameNumber(String a, String b) {
  String lastDigits(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  return lastDigits(a) == lastDigits(b);
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _storage = StorageService();
  final _sms = DeviceSmsGateway();
  List<EmergencyContact> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final contacts = await _storage.getContacts();
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _loading = false;
    });
  }

  Future<void> _addOrEditContact({EmergencyContact? existing}) async {
    final contact = await showDialog<EmergencyContact>(
      context: context,
      builder: (_) => _ContactDialog(
        existing: existing,
        otherPhones: [
          for (final c in _contacts)
            if (c.id != existing?.id) c.phone,
        ],
      ),
    );
    if (contact == null) return;
    setState(() {
      if (existing != null) {
        final idx = _contacts.indexWhere((c) => c.id == existing.id);
        _contacts[idx] = contact;
      } else {
        _contacts.add(contact);
      }
    });
    await _storage.saveContacts(_contacts);
  }

  Future<void> _deleteContact(EmergencyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${contact.name}?'),
        content: const Text('They will no longer get your SOS alerts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _contacts.removeWhere((c) => c.id == contact.id));
    await _storage.saveContacts(_contacts);
  }

  /// Proves the setup works before it's needed, and lets contacts know why
  /// they might hear from the app.
  Future<void> _sendTest(EmergencyContact contact) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Send test to ${contact.name}?'),
        content: const Text(
          'They will get one SMS saying this is only a test.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final profile = await _storage.getProfile();
    final settings = await _storage.getSettings();
    final message = SosMessages.test(
      profile['name'] ?? '',
      language: settings.language,
    );
    final result = await _sms.send(contact.phone, message);
    final text = switch (result) {
      SmsResult.sent => 'Test sent to ${contact.name}',
      SmsResult.failed => 'Could not send. Check your signal and SMS balance.',
      _ => await _sms.openComposer([contact.phone], message)
          ? 'Press send in your messages app'
          : 'Could not open your messages app',
    };
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditContact(),
        icon: const Icon(Icons.add),
        label: const Text('Add contact'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _contacts.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline, size: 64),
                          SizedBox(height: 12),
                          Text(
                            'No trusted contacts yet.\nAdd family or friends who '
                            'should be alerted\nduring an emergency.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) {
                      final contact = _contacts[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.only(left: 14),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Text(
                              contact.name.isNotEmpty
                                  ? contact.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(contact.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle:
                              Text('${contact.relation} • ${contact.phone}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Call ${contact.name}',
                                icon: const Icon(Icons.call,
                                    color: AppColors.success),
                                onPressed: () => callNumber(contact.phone),
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'More options',
                                onSelected: (action) => switch (action) {
                                  'test' => _sendTest(contact),
                                  'edit' =>
                                    _addOrEditContact(existing: contact),
                                  _ => _deleteContact(contact),
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'test',
                                    child: Text('Send test alert'),
                                  ),
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Remove'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _ContactDialog extends StatefulWidget {
  final EmergencyContact? existing;
  final List<String> otherPhones;
  const _ContactDialog({this.existing, required this.otherPhones});

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.existing?.name);
  late final _phoneCtrl = TextEditingController(text: widget.existing?.phone);
  late final _relationCtrl =
      TextEditingController(text: widget.existing?.relation);
  String? _pickError;

  /// Uses the phone's own contact picker, which hands over only the person
  /// chosen, so the app never needs permission to read the contact list.
  Future<void> _pickFromPhone() async {
    setState(() => _pickError = null);
    try {
      final picked = await FlutterNativeContactPicker().selectPhoneNumber();
      if (picked == null || !mounted) return;
      final number = picked.selectedPhoneNumber ?? '';
      setState(() {
        _nameCtrl.text = picked.fullName ?? '';
        _phoneCtrl.text = cleanPhoneNumber(number) ?? number;
      });
      _formKey.currentState!.validate();
    } on PlatformException catch (e) {
      debugPrint('Contact picker failed: ${e.message}');
      if (mounted) {
        setState(() => _pickError = "Couldn't open your contacts. Type the "
            'details instead.');
      }
    }
  }

  String? _validatePhone(String? value) {
    final phone = cleanPhoneNumber(value ?? '');
    if (phone == null) return 'Enter a valid phone number';
    if (widget.otherPhones.any((other) => isSameNumber(other, phone))) {
      return 'This number is already in your contacts';
    }
    return null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _relationCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final relation = _relationCtrl.text.trim();
    Navigator.pop(
      context,
      EmergencyContact(
        id: widget.existing?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameCtrl.text.trim(),
        phone: cleanPhoneNumber(_phoneCtrl.text)!,
        relation: relation.isEmpty ? 'Contact' : relation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Contact' : 'Edit Contact'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _pickFromPhone,
                icon: const Icon(Icons.contacts),
                label: const Text('Choose from phone contacts'),
              ),
              if (_pickError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _pickError!,
                    style: const TextStyle(color: AppColors.sosRed),
                  ),
                ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone number'),
                validator: _validatePhone,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _relationCtrl,
                textCapitalization: TextCapitalization.words,
                decoration:
                    const InputDecoration(labelText: 'Relation (e.g. Mother)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
