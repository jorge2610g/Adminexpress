import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_panel.dart';
import 'core/supabase_client.dart';

const adminExpressVersion = 'Adminexpress v1.0.0 · build 1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? startupError;
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  } catch (e) {
    startupError = e;
  }

  runApp(AdminExpressApp(startupError: startupError));
}

class AdminExpressApp extends StatelessWidget {
  final Object? startupError;

  const AdminExpressApp({super.key, this.startupError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adminexpress',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0B57D0),
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
      ),
      home: startupError == null
          ? const _AdminAuthGate()
          : _StartupError(error: startupError!),
    );
  }
}

class _AdminAuthGate extends StatefulWidget {
  const _AdminAuthGate();

  @override
  State<_AdminAuthGate> createState() => _AdminAuthGateState();
}

class _AdminAuthGateState extends State<_AdminAuthGate> {
  StreamSubscription<AuthState>? subscription;
  int revision = 0;

  @override
  void initState() {
    super.initState();
    subscription = supabase.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() => revision++);
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (mounted) setState(() => revision++);
  }

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;
    if (session == null) {
      return _AdminLogin(
        key: ValueKey('login-' + revision.toString()),
        onSignedIn: () => setState(() => revision++),
      );
    }

    return ExpressAdminPanel(onExit: _logout);
  }
}

class _AdminLogin extends StatefulWidget {
  final VoidCallback onSignedIn;

  const _AdminLogin({super.key, required this.onSignedIn});

  @override
  State<_AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<_AdminLogin> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  bool obscure = true;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final mail = email.text.trim();
    final pass = password.text;
    if (mail.isEmpty || pass.isEmpty || busy) return;

    setState(() {
      busy = true;
      error = null;
    });

    try {
      await supabase.auth.signInWithPassword(email: mail, password: pass);
      final isAdmin = await supabase.rpc('is_admin') == true;
      if (!isAdmin) {
        await supabase.auth.signOut();
        throw Exception('Esta cuenta no tiene acceso de administrador.');
      }
      if (mounted) widget.onSignedIn();
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      body: Row(
        children: [
          if (wide) const Expanded(flex: 6, child: _AdminBrandPanel()),
          Expanded(
            flex: 5,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Adminexpress',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Panel administrativo de Express Delivery',
                            style: TextStyle(color: Color(0xFF667085)),
                          ),
                          const SizedBox(height: 26),
                          TextField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Correo administrador',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: password,
                            obscureText: obscure,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => obscure = !obscure),
                                icon: Icon(
                                  obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              error!,
                              style: const TextStyle(
                                color: Color(0xFFD92D20),
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: busy ? null : _submit,
                              icon: busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.login_rounded),
                              label: const Text('Ingresar al panel'),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Center(
                            child: Text(
                              adminExpressVersion,
                              style: TextStyle(
                                color: Color(0xFF98A2B3),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminBrandPanel extends StatelessWidget {
  const _AdminBrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(54),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF073B8C),
            Color(0xFF0B57D0),
            Color(0xFF39A0FF),
          ],
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFF0B57D0),
                  size: 30,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'EXPRESS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Spacer(),
          Text(
            'Administra Express\ndesde un solo lugar.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Operación, conductores, seguridad, tarifas, builds y releases.',
            style: TextStyle(
              color: Color(0xFFDCEAFF),
              fontSize: 17,
              height: 1.45,
            ),
          ),
          Spacer(),
          Text(
            'Adminexpress · Solo web',
            style: TextStyle(color: Color(0xFFBFD8FF)),
          ),
        ],
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  final Object error;

  const _StartupError({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 52),
                  const SizedBox(height: 14),
                  const Text(
                    'Adminexpress no pudo iniciar',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(error.toString(), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
