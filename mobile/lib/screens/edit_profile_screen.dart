import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../state/providers.dart';
import '../widgets/animated_number.dart';
import '../widgets/animated_ring.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  String? _birth; // YYYY-MM-DD
  String? _gender; // MALE | FEMALE
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = ref.read(authProvider).value;
    _name = TextEditingController(text: u?.name ?? '');
    _email = TextEditingController(text: u?.email ?? '');
    _birth = u?.birthDate;
    _gender = u?.gender;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  String _fmt(String ymd) {
    final p = ymd.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : ymd;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _birth != null ? DateTime.tryParse(_birth!) ?? DateTime(now.year - 25) : DateTime(now.year - 25);
    final d = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(now.year - 110), lastDate: DateTime(now.year - 5, now.month, now.day), helpText: 'Tanggal lahir');
    if (d != null) setState(() => _birth = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final u = ref.read(authProvider).value;
    // Kirim hanya field yang diisi dan berubah.
    final fields = <String, dynamic>{
      if (_name.text.trim().isNotEmpty && _name.text.trim() != (u?.name ?? '')) 'name': _name.text.trim(),
      if (_email.text.trim().isNotEmpty && _email.text.trim() != (u?.email ?? '')) 'email': _email.text.trim(),
      if (_birth != null && _birth != u?.birthDate) 'birthDate': _birth,
      if (_gender != null && _gender != u?.gender) 'gender': _gender,
    };
    if (fields.isEmpty) {
      context.pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).updateProfile(fields);
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil disimpan')));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = ref.watch(authProvider).value;
    final pct = u?.completionPercent ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFE5F6F3), borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox.expand(child: AnimatedProgressRing(value: pct / 100, backgroundColor: Colors.white, color: brandColor)),
                  AnimatedNumber(value: pct, from: 0, format: (v) => '$v%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(pct >= 100 ? 'Profilmu sudah lengkap. Terima kasih!' : 'Lengkapi profil supaya kami bisa mengenalmu lebih baik.', style: Theme.of(context).textTheme.bodyMedium)),
            ]),
          ),
          const SizedBox(height: 22),
          TextFormField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nama lengkap', prefixIcon: Icon(Icons.person_outline)), validator: (v) => (v != null && v.trim().isNotEmpty && v.trim().length < 2) ? 'Minimal 2 karakter' : null),
          const SizedBox(height: 14),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
            validator: (v) => (v != null && v.trim().isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) ? 'Format email tidak valid' : null,
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Tanggal lahir', prefixIcon: Icon(Icons.cake_outlined), suffixIcon: Icon(Icons.calendar_month_outlined)),
              child: Text(_birth == null ? 'Pilih tanggal' : _fmt(_birth!), style: TextStyle(color: _birth == null ? Theme.of(context).hintColor : null)),
            ),
          ),
          const SizedBox(height: 18),
          Text('Jenis kelamin', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            emptySelectionAllowed: true,
            segments: const [ButtonSegment(value: 'MALE', label: Text('Laki-laki'), icon: Icon(Icons.male)), ButtonSegment(value: 'FEMALE', label: Text('Perempuan'), icon: Icon(Icons.female))],
            selected: {?_gender},
            onSelectionChanged: (s) => setState(() => _gender = s.isEmpty ? null : s.first),
          ),
          const SizedBox(height: 14),
          TextFormField(initialValue: '+${u?.phone ?? ''}', enabled: false, decoration: const InputDecoration(labelText: 'Nomor HP (tidak bisa diubah)', prefixIcon: Icon(Icons.phone_outlined))),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 24),
          FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Simpan')),
        ]),
      ),
    );
  }
}
