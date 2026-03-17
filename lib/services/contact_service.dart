import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// ContactService — stores and retrieves up to 5 emergency contacts.
/// Each contact has a name and phone number.
/// Data is persisted locally using SharedPreferences.

class EmergencyContact {
  final String name;
  final String phone;

  EmergencyContact({required this.name, required this.phone});

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(name: json['name'], phone: json['phone']);
}

class ContactService {
  static const String _key = 'emergency_contacts';
  static const int maxContacts = 5;

  List<EmergencyContact> contacts = [];

  /// Load saved contacts from local storage
  Future<void> loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    contacts = raw
        .map((e) => EmergencyContact.fromJson(jsonDecode(e)))
        .toList();
    print("[ContactService] Loaded ${contacts.length} contacts");
  }

  /// Save contacts to local storage
  Future<void> saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = contacts.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_key, raw);
    print("[ContactService] Saved ${contacts.length} contacts");
  }

  /// Add a new contact (max 5)
  Future<bool> addContact(EmergencyContact contact) async {
    if (contacts.length >= maxContacts) return false;
    contacts.add(contact);
    await saveContacts();
    return true;
  }

  /// Remove a contact by index
  Future<void> removeContact(int index) async {
    if (index < 0 || index >= contacts.length) return;
    contacts.removeAt(index);
    await saveContacts();
  }

  /// Update a contact
  Future<void> updateContact(int index, EmergencyContact contact) async {
    if (index < 0 || index >= contacts.length) return;
    contacts[index] = contact;
    await saveContacts();
  }

  List<String> getPhoneNumbers() => contacts.map((c) => c.phone).toList();
}
