import 'package:get/get.dart';
import 'dart:typed_data';

import 'package:chat_app/core/constants/api_entpoint.dart';
import 'package:chat_app/feature/profile/data/datasource/profile_remote_data_source.dart';
import 'package:chat_app/feature/profile/domain/entity/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.datasource});
  final ProfileRemoteDataSource datasource;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _status = TextEditingController();
  UserProfile? _profile;
  String? _error;
  bool _saving = false;
  bool _picking = false;
  XFile? _photo;
  Uint8List? _preview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final profile = await widget.datasource.load(requireFresh: true);
      if (!mounted) return;
      _name.text = profile.name;
      _status.text = profile.statusMessage ?? '';
      setState(() => _profile = profile);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _pickPhoto() async {
    setState(() => _picking = true);
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (bytes.length > 5000 * 1024) {
        throw Exception('Choose a photo smaller than 5 MB.');
      }
      if (!mounted) return;
      setState(() {
        _photo = photo;
        _preview = bytes;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final profile = await widget.datasource.update(
        name: _name.text,
        statusMessage: _status.text,
        avatar: _photo,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(profile);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _status.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final avatar = profile?.avatarUrl;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: Text('Edit Profile'.tr)),
        body: profile == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          TextButton(onPressed: _load, child: Text('Retry'.tr)),
                        ],
                      ),
              )
            : Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: ClipOval(
                        child: SizedBox(
                          width: 100,
                          height: 100,
                          child: _preview != null
                              ? Image.memory(_preview!, fit: BoxFit.cover)
                              : avatar != null && avatar.isNotEmpty
                              ? Image.network(
                                  Uri.parse(
                                    ApiEntpoint.url,
                                  ).resolve(avatar).toString(),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, error, stack) =>
                                      const Icon(Icons.person, size: 64),
                                )
                              : const Icon(Icons.person, size: 64),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _saving || _picking ? null : _pickPhoto,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(
                        _picking ? 'Loading photo...' : 'Change photo'.tr,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _name,
                      enabled: !_saving,
                      maxLength: 255,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Name'.tr,
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Enter your name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _status,
                      enabled: !_saving,
                      maxLength: 255,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'About / status'.tr,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: profile.email,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Email'.tr,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving || _picking ? null : _save,
                      child: Text(_saving ? 'Saving...'.tr : 'Save changes'.tr),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
