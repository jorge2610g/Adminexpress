import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_panel.dart';
import 'core/supabase_client.dart';
import 'core/admin_environment_navigation.dart';
import 'core/admin_design_tokens.dart';
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
      // Preview and Production have distinct browser sessions on the same
      // origin. Keep Production's DEFAULT storage key unchanged for existing
      // sessions; only Preview receives its own session key.
      authOptions: adminIsPreview
          ? FlutterAuthClientOptions(
              localStorage: SharedPreferencesLocalStorage(
                persistSessionKey: adminPreviewAuthSessionStorageKey,
              ),
            )
          : const FlutterAuthClientOptions(),
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
      title: adminIsPreview ? 'Adminexpress · Prueba' : 'Adminexpress · Producción',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AdminColors.blue,
          surface: AdminColors.surface,
        ),
        scaffoldBackgroundColor: AdminColors.bg,
        cardTheme: CardThemeData(
          color: AdminColors.surface,
          surfaceTintColor: AdminColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminRadius.card),
            side: const BorderSide(color: AdminColors.border),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AdminColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminRadius.control),
            borderSide: const BorderSide(color: AdminColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminRadius.control),
            borderSide: const BorderSide(color: AdminColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminRadius.control),
            borderSide: const BorderSide(color: AdminColors.blue, width: 1.5),
          ),
        ),
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

  Future<_ExpressPanelAccess> _resolveAccess() async {
    final isAdmin = await supabase.rpc('is_admin') == true;
    if (isAdmin) {
      // Access is checked server-side for the compiled page's environment,
      // including OAuth redirects and restored browser sessions.
      final allowed = await supabase.rpc(
        'admin_environment_allowed',
        params: {'p_channel': adminRuntimeChannel},
      ) == true;
      return allowed
          ? _ExpressPanelAccess.admin
          : _ExpressPanelAccess.denied;
    }
    // Preview must not query real partner data in shared Supabase.
    if (adminIsPreview) return _ExpressPanelAccess.denied;

    final raw = await supabase.rpc('partner_my_dashboard');
    if (raw is List && raw.isNotEmpty) {
      return _ExpressPanelAccess.partner;
    }
    return _ExpressPanelAccess.denied;
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

    return FutureBuilder<_ExpressPanelAccess>(
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
            message: snapshot.error.toString(),
            onExit: _logout,
          );
        }

        switch (snapshot.data ?? _ExpressPanelAccess.denied) {
          case _ExpressPanelAccess.admin:
            return ExpressAdminPanel(onExit: _logout);
          case _ExpressPanelAccess.partner:
            return PartnerExpressPanel(onExit: _logout);
          case _ExpressPanelAccess.denied:
            return _AccessDenied(
              title: adminIsPreview
                  ? 'Cuenta sin acceso a Prueba'
                  : 'Cuenta sin acceso a Producción',
              message: adminIsPreview
                  ? 'La cuenta ingresada no está autorizada para Preview. '
                    'Cierra sesión y utiliza las credenciales de prueba.'
                  : 'Esta cuenta no tiene acceso administrativo a '
                    'Producción ni una organización asignada.',
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
      final isAdmin = await supabase.rpc('is_admin') == true;
      final allowedForPage = isAdmin &&
          await supabase.rpc(
                'admin_environment_allowed',
                params: {'p_channel': adminRuntimeChannel},
              ) ==
              true;
      if (isAdmin && !allowedForPage) {
        // Reject the wrong administrator identity before entering the panel.
        await supabase.auth.signOut(scope: SignOutScope.local);
        throw Exception(
          'Esta cuenta no tiene autorización para este entorno. '
          'Utiliza las credenciales administrativas correspondientes.',
        );
      }
      var hasPartnerAccess = false;
      if (!isAdmin && !adminIsPreview) {
        final raw = await supabase.rpc('partner_my_dashboard');
        hasPartnerAccess = raw is List && raw.isNotEmpty;
      }
      if (!allowedForPage && !hasPartnerAccess) {
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

  Future<void> _googleLogin() async {
    if (!adminIsPreview || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final started = await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: adminPreviewGoogleOAuthRedirectUrl,
      );
      if (!started && mounted) {
        setState(() => error = 'No se pudo iniciar sesión con Google.');
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AdminBreakpoints.desktop;
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
                          Text(
                            adminIsPreview
                                ? 'Acceso de Prueba · sesión independiente'
                                : 'Acceso de Producción',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: adminIsPreview
                                  ? const Color(0xFF935B0B)
                                  : const Color(0xFF156C41),
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
                          if (adminIsPreview) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: OutlinedButton.icon(
                                onPressed: busy ? null : _googleLogin,
                                icon: const Icon(Icons.account_circle_outlined),
                                label: const Text('Acceder con Google · Preview'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Necesitas permisos administrativos para el canal '
                              'de Prueba en Supabase principal.',
                              style: TextStyle(
                                color: Color(0xFF667085),
                                fontSize: 11,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          const Center(
                            child: AdminEnvironmentLinkButton(),
                          ),
                          const SizedBox(height: 7),
                          const Center(
                            child: Text(
                              'Cada página utiliza su canal autorizado.',
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
        gradient: AdminGradients.hero,
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
