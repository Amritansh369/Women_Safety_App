import 'package:flutter/material.dart';
import '../models/emergency_contact.dart';
import '../services/storage_service.dart';
import '../services/sos_service.dart';
import '../theme.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _storage = StorageService();
  final _sosService = SosService();
  List<EmergencyContact> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final contacts = await _storage.getContacts();
    setState(() {
      _contacts = contacts;
      _loading = false;
    });
  }

  Future<void> _addOrEditContact({EmergencyContact? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final relationCtrl = TextEditingController(text: existing?.relation ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Contact' : 'Edit Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: relationCtrl,
              decoration:
                  const InputDecoration(labelText: 'Relation (e.g. Mother)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );

    if (result == true &&
        nameCtrl.text.trim().isNotEmpty &&
        phoneCtrl.text.trim().isNotEmpty) {
      final contact = EmergencyContact(
        id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        relation: relationCtrl.text.trim().isEmpty
            ? 'Contact'
            : relationCtrl.text.trim(),
      );

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
  }

  Future<void> _deleteContact(EmergencyContact contact) async {
    setState(() => _contacts.removeWhere((c) => c.id == contact.id));
    await _storage.saveContacts(_contacts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _addOrEditContact(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _contacts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_outline,
                              size: 64, color: Colors.black26),
                          const SizedBox(height: 12),
                          const Text(
                            'No trusted contacts yet.\nAdd family or friends who '
                            'should be alerted\nduring an emergency.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) {
                      final contact = _contacts[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
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
                                icon: const Icon(Icons.call,
                                    color: AppColors.success),
                                onPressed: () =>
                                    _sosService.callContact(contact.phone),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.black54),
                                onPressed: () =>
                                    _addOrEditContact(existing: contact),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: AppColors.sosRed),
                                onPressed: () => _deleteContact(contact),
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
