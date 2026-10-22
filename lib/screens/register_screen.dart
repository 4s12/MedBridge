import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../utils/validators.dart';
import '../widgets/auth_layout.dart';
import '../widgets/common.dart';

/// Password strength indicator colours.
const List<Color> _strengthColors = [
  Colors.red,       // Very Weak
  Colors.orange,    // Weak
  Colors.amber,     // Fair
  Colors.lightGreen, // Strong
  Colors.green,     // Very Strong
];

/// Registration screen matching the blueprint fields.
///
/// Patient: Name, DOB, Gender, Phone (+91), Email, Password.
/// Doctor: + Specialization, Hospital, Experience, Fee, Medical Reg No.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _hospital = TextEditingController();
  final _experience = TextEditingController();
  final _fee = TextEditingController();
  final _medRegNo = TextEditingController();

  String _role = 'patient';
  String? _spec;
  String _gender = 'Male';
  DateTime? _dob;
  String _countryCode = '+91';
  bool _hide = true;
  bool _hideConfirm = true;
  bool _loading = false;
  String? _error;

  // Live password strength tracking
  double _pwStrength = 0;
  String _pwLabel = '';
  int _pwColorIdx = 0;

  @override
  void initState() {
    super.initState();
    _password.addListener(_updateStrength);
  }

  @override
  void dispose() {
    _password.removeListener(_updateStrength);
    for (final c in [
      _name, _phone, _email, _password, _confirm,
      _hospital, _experience, _fee, _medRegNo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _updateStrength() {
    final result = passwordStrength(_password.text);
    setState(() {
      _pwStrength = result.strength;
      _pwLabel = result.label;
      _pwColorIdx = result.colorIndex;
    });
  }

  Future<void> _pickDOB() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Select Date of Birth',
    );
    if (picked != null) {
      setState(() => _dob = picked);
    }
  }

  Future<void> _register() async {
    // Validate DOB separately since it's not a text field
    final dobError = validateDOB(_dob);
    if (dobError != null) {
      showMsg(context, dobError, error: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.register(
        name: _name.text,
        email: _email.text,
        password: _password.text,
        phone: '$_countryCode${_phone.text.trim()}',
        role: _role,
        gender: _gender,
        dob: _dob!,
        specialization: _spec ?? '',
        hospital: _hospital.text,
        experienceYears: int.tryParse(_experience.text.trim()) ?? 0,
        fee: int.tryParse(_fee.text.trim()) ?? 0,
        medicalRegNo: _medRegNo.text.trim(),
      );
      if (mounted) {
        // Back to the root; AuthGate handles verification flow.
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.message(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Lays out two fields side-by-side on wide screens, stacked otherwise.
  Widget _pair(bool isWide, Widget a, Widget b) {
    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [a, const SizedBox(height: 14), b],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 14),
        Expanded(child: b),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDoctor = _role == 'doctor';
    return AuthLayout(
      formMaxWidth: 560,
      mobileAppBar: AppBar(title: const Text('Create Account')),
      builder: (context, isWide) => Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── Header (wide screens only; phones use the AppBar) ───
                  if (isWide) ...[
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Back to login',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: 4),
                        const Text('Create Account',
                            style: TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 52, top: 2),
                      child: Text('Join MedBridge in less than a minute',
                          style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ─── Role toggle ───
                  const Text('I am a',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'patient',
                          label: Text('Patient'),
                          icon: Icon(Icons.person)),
                      ButtonSegment(
                          value: 'doctor',
                          label: Text('Doctor'),
                          icon: Icon(Icons.medical_services)),
                    ],
                    selected: {_role},
                    onSelectionChanged: (s) =>
                        setState(() => _role = s.first),
                  ),
                  const SizedBox(height: 16),

                  // ─── Full Name ───
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.badge_outlined)),
                    validator: validateName,
                  ),
                  const SizedBox(height: 14),

                  // ─── Date of Birth + Gender ───
                  _pair(
                  isWide,
                  InkWell(
                    onTap: _pickDOB,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Date of Birth',
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                        errorText: _dob == null && _error != null &&
                                _error!.contains('Date of birth')
                            ? 'Date of birth is required'
                            : null,
                      ),
                      child: Text(
                        _dob == null
                            ? 'DD/MM/YYYY'
                            : DateFormat('dd/MM/yyyy').format(_dob!),
                        style: TextStyle(
                          color: _dob == null ? Colors.grey : null,
                        ),
                      ),
                    ),
                  ),

                  // ─── Gender ───
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: const InputDecoration(
                        labelText: 'Gender',
                        prefixIcon: Icon(Icons.person_outline)),
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _gender = v);
                    },
                  ),
                  ),
                  const SizedBox(height: 14),

                  // ─── Phone with country code ───
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 90,
                        child: DropdownButtonFormField<String>(
                          initialValue: _countryCode,
                          decoration: const InputDecoration(
                            labelText: 'Code',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 14),
                          ),
                          items: const [
                            DropdownMenuItem(value: '+91', child: Text('+91')),
                            DropdownMenuItem(value: '+1', child: Text('+1')),
                            DropdownMenuItem(value: '+44', child: Text('+44')),
                            DropdownMenuItem(value: '+61', child: Text('+61')),
                            DropdownMenuItem(value: '+971', child: Text('+971')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _countryCode = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              prefixIcon: Icon(Icons.phone_outlined),
                              hintText: '9876543210'),
                          validator: validatePhone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ─── Email ───
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'e.g. name@gmail.com',
                        helperText: 'Only @gmail.com addresses are accepted',
                        prefixIcon: Icon(Icons.email_outlined)),
                    validator: validateEmail,
                  ),

                  // ─── Doctor-specific fields ───
                  if (isDoctor) ...[
                    const SizedBox(height: 14),
                    _pair(
                    isWide,
                    DropdownButtonFormField<String>(
                      initialValue: _spec,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Specialization',
                          prefixIcon: Icon(Icons.healing_outlined)),
                      items: [
                        for (final s in kSpecializations)
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: (v) => setState(() => _spec = v),
                      validator: (v) =>
                          v == null ? 'Select a specialization' : null,
                    ),
                    TextFormField(
                      controller: _hospital,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                          labelText: 'Hospital / Clinic',
                          prefixIcon: Icon(Icons.local_hospital_outlined)),
                      validator: (v) => validateRequired(v, 'Hospital'),
                    ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _experience,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                                labelText: 'Experience (yrs)'),
                            validator: validateExperience,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _fee,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                                labelText: 'Fee (₹)'),
                            validator: validateFee,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _medRegNo,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                          labelText: 'Medical Registration No.',
                          hintText: 'e.g. MCI-12345',
                          prefixIcon: Icon(Icons.verified_outlined)),
                      validator: validateMedRegNo,
                    ),
                  ],
                  const SizedBox(height: 14),

                  // ─── Password with strength meter ───
                  TextFormField(
                    controller: _password,
                    obscureText: _hide,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _hide ? 'Show password' : 'Hide password',
                        icon: Icon(
                            _hide ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                      helperText:
                          'Min 8 chars: 1 uppercase, 1 lowercase, 1 digit, 1 special',
                      helperMaxLines: 2,
                    ),
                    validator: validatePassword,
                  ),

                  // Password strength meter
                  if (_password.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _pwStrength,
                              backgroundColor: Colors.grey.shade300,
                              color: _strengthColors[_pwColorIdx],
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _pwLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _strengthColors[_pwColorIdx],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Show individual requirement checks
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _reqChip('8+ chars', _password.text.length >= 8),
                        _reqChip('A-Z', RegExp(r'[A-Z]').hasMatch(_password.text)),
                        _reqChip('a-z', RegExp(r'[a-z]').hasMatch(_password.text)),
                        _reqChip('0-9', RegExp(r'[0-9]').hasMatch(_password.text)),
                        _reqChip('!@#\$',
                            RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/~`]')
                                .hasMatch(_password.text)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),

                  // ─── Confirm Password ───
                  TextFormField(
                    controller: _confirm,
                    obscureText: _hideConfirm,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _hideConfirm ? 'Show' : 'Hide',
                        icon: Icon(_hideConfirm
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _hideConfirm = !_hideConfirm),
                      ),
                    ),
                    validator: (v) =>
                        v != _password.text ? 'Passwords do not match' : null,
                  ),

                  // ─── Error display ───
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: TextStyle(color: Colors.red.shade800)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ─── Register button ───
                  ElevatedButton(
                    onPressed: _loading ? null : _register,
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : Text(isDoctor
                            ? 'REGISTER DOCTOR'
                            : 'REGISTER PATIENT'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Already have an account? Login',
                        style: TextStyle(color: kPrimary)),
                  ),
                ],
              ),
            ),
    );
  }

  /// Small chip showing whether a password requirement is met.
  Widget _reqChip(String label, bool met) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check_circle : Icons.cancel,
          size: 14,
          color: met ? Colors.green : Colors.red.shade400,
        ),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
              fontSize: 11,
              color: met ? Colors.green : Colors.red.shade400,
            )),
      ],
    );
  }
}
