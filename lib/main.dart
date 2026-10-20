import 'dart:async';

import 'package:flutter/material.dart';
import 'core/admin_friendly_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_panel.dart';
import 'core/supabase_client.dart';
import 'partner_panel.dart';

const adminExpressVersion = 'Adminexpress v1.0.1 · build 2';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? startupError;
  try {
    validateAdminDeployment();
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );  } catch (e) {
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
      title: 'Adminexpress · Central',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0B57D0),
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        fontFamily: 'Plus Jakarta Sans',
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

enum _ExpressPanelAccess { admin, partner, denied }

class _AdminAuthGateState extends State<_AdminAuthGate> {
  StreamSubscription<AuthState>? subscription;
  int revision = 0;

  Future<({ _ExpressPanelAccess access, String? channel })> _resolveAccess() async {
    final rawAccess = await supabase.rpc('admin_access_context');
    if (rawAccess is Map) {
      final access = Map<String, dynamic>.from(rawAccess);
      final channel = access['runtime_environment']?.toString();
      final allowed = access['allowed'] == true &&
          (channel == 'preview' || channel == 'production') &&
          await supabase.rpc(
                'admin_environment_allowed',
                params: {'p_channel': channel},
              ) ==
              true;
      if (allowed) {
        return (access: _ExpressPanelAccess.admin, channel: channel);
      }
    }

    final raw = await supabase.rpc('partner_my_dashboard');
    if (raw is List && raw.isNotEmpty) {
      return (access: _ExpressPanelAccess.partner, channel: 'production');
    }
    return (access: _ExpressPanelAccess.denied, channel: null);
  }

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
    await supabase.auth.signOut(scope: SignOutScope.local);
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

    return FutureBuilder<({ _ExpressPanelAccess access, String? channel })>(
      key: ValueKey(
        'access-' + session.user.id + '-' + revision.toString(),
      ),
      future: _resolveAccess(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _AccessDenied(
            title: 'No se pudo validar tu acceso',
            message: friendlyError(snapshot.error),
            onExit: _logout,
          );
        }

        final resolved = snapshot.data ??
            (access: _ExpressPanelAccess.denied, channel: null);

        switch (resolved.access) {
          case _ExpressPanelAccess.admin:
            return ExpressAdminPanel(
              onExit: _logout,
              initialChannel: resolved.channel!,
            );
          case _ExpressPanelAccess.partner:
            return PartnerExpressPanel(onExit: _logout);
          case _ExpressPanelAccess.denied:
            return _AccessDenied(
              title: 'Cuenta sin acceso administrativo',
              message:
                  'Esta cuenta no tiene acceso al panel administrativo. '
                  'Cierra sesión y utiliza las credenciales correspondientes.',
              onExit: _logout,
            );
        }
      },
    );
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

      final rawAccess = await supabase.rpc('admin_access_context');
      final access = rawAccess is Map
          ? Map<String, dynamic>.from(rawAccess)
          : <String, dynamic>{};
      final channel = access['runtime_environment']?.toString();
      final hasAdminAccess = access['allowed'] == true &&
          (channel == 'preview' || channel == 'production') &&
          await supabase.rpc(
                'admin_environment_allowed',
                params: {'p_channel': channel},
              ) ==
              true;

      if (hasAdminAccess) {
        if (mounted) widget.onSignedIn();
        return;
      }

      final raw = await supabase.rpc('partner_my_dashboard');
      final hasPartnerAccess = raw is List && raw.isNotEmpty;
      if (!hasPartnerAccess) {
        await supabase.auth.signOut(scope: SignOutScope.local);
        throw Exception(
          'Esta cuenta no tiene acceso de administrador ni de organización.',
        );
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
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFDDE6F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x140F172A),
                          blurRadius: 44,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Adminexpress',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Acceso al panel administrativo',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF156C41),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Panel administrativo de Express Delivery',
                            style: TextStyle(color: Color(0xFF667085)),
                          ),
                          const SizedBox(height: 26),
                          const Text(
                            'Correo administrador',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Semantics(
                            label: 'Correo administrador',
                            textField: true,
                            child: TextField(
                              controller: email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.mail_outline_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Contraseña',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Semantics(
                            label: 'Contraseña',
                            textField: true,
                            child: TextField(
                              controller: password,
                              obscureText: obscure,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
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
                          const SizedBox(height: 8),
                          const Text(
                            'Tu cuenta define si ves datos de Prueba o de Producción '
                            'y qué información puedes ver.',
                            style: TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Center(
                            child: Text(
                              'Tu cuenta define qué información puedes ver.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11, color: Color(0xFF667085),
                              ),
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
            Color(0xFF0B1220),
            Color(0xFF0F2854),
            Color(0xFF174B91),
            Color(0xFF0D6B8D),
          ],
          stops: [0.0, 0.38, 0.72, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2563EB), Color(0xFF22D3EE)],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D22D3EE),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'EXPRESS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          const Text(
            'Administra Express\ndesde un solo lugar.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 44,
              height: 1.08,
              letterSpacing: -1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          const SizedBox(
            width: 460,
            child: Text(
              'Operación, conductores, seguridad, tarifas, builds y releases.',
              style: TextStyle(
                color: Color(0xFFD7E7FA),
                fontSize: 17,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _BrandChip(icon: Icons.map_outlined, label: 'Operación'),
              _BrandChip(icon: Icons.drive_eta_outlined, label: 'Conductores'),
              _BrandChip(icon: Icons.shield_outlined, label: 'Seguridad'),
            ],
          ),
          const Spacer(),
          const Text(
            'Adminexpress · Solo web',
            style: TextStyle(
              color: Color(0xFF8FB4E8),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BrandChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFFD7E7FA)),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD7E7FA),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}


class _AccessDenied extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onExit;

  const _AccessDenied({
    required this.title,
    required this.message,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 52,
                    color: Color(0xFFD92D20),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF667085)),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onExit,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
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
                  Text(friendlyError(error), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
