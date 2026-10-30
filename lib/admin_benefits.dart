import 'package:flutter/material.dart';

import 'core/admin_friendly_error.dart';
import 'core/supabase_client.dart';

const _adminBlue = Color(0xFF155EEF);
const _ink = Color(0xFF101828);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE4E7EC);

const _categories = <(String, String, IconData)>[
  ('coupon', 'Cupones y promociones', Icons.local_offer_outlined),
  ('loyalty', 'Fidelidad', Icons.loyalty_outlined),
  ('referral', 'Referidos', Icons.people_alt_outlined),
  ('driver_challenge', 'Retos', Icons.flag_outlined),
];

String _stateLabel(String state) => switch (state) {
      'draft' => 'Borrador',
      'active' => 'Activo',
      'paused' => 'Inactivo',
      'closed' => 'Terminado',
      _ => state,
    };

class AdminBenefitsPage extends StatefulWidget {
  const AdminBenefitsPage({
    super.key,
    required this.channel,
    required this.zoneId,
  });

  final String channel;
  final String? zoneId;

  @override
  State<AdminBenefitsPage> createState() => _AdminBenefitsPageState();
}

class _AdminBenefitsPageState extends State<AdminBenefitsPage> {
  late Future<List<Map<String, dynamic>>> _future;
  late Future<Map<String, dynamic>> _referralDashboardFuture;
  String _category = 'coupon';
  String _couponTab = 'coupons';
  // Open the active business model first: driver referrals earn a percentage
  // from each approved plan payment, not a trip-count reward.
  String _referralTab = 'mlm';
  String _discount = 'fixed';
  String _filter = 'all';
  String _referralFilter = 'all';
  String _referralTypeFilter = 'all';
  String _serviceMode = 'transport';
  String _serviceType = 'all';
  String _audience = 'passengers';
  String _targetAudience = 'all';
  String _rewardDestination = 'wallet';
  String _referrerType = 'fixed';
  String _referredType = 'fixed';
  String _referrerDestination = 'wallet';
  String _referredDestination = 'wallet';
  String _trigger = 'first_trip';
  String _period = 'weekly';
  bool _firstRide = false;
  bool _sameDayCredits = false;
  bool _lifetime = true;
  bool _exclusive = false;
  bool _enabled = false;
  bool _saving = false;
  DateTime _startsAt = DateTime.now();
  DateTime? _endsAt;

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _code = TextEditingController();
  final _value = TextEditingController();
  final _maxDiscount = TextEditingController();
  final _minFare = TextEditingController();
  final _threshold = TextEditingController();
  final _leaderPercent = TextEditingController();
  final _benefitMonths = TextEditingController();
  final _driverNoCommission = TextEditingController();
  final _dailyDriverCap = TextEditingController();
  final _maxPerCustomer = TextEditingController();
  final _maxTotalRewards = TextEditingController();
  final _referrerReward = TextEditingController();
  final _referredReward = TextEditingController();
  final _maxReferrals = TextEditingController();
  final _maxTotalUses = TextEditingController();
  final _usesPerUser = TextEditingController();
  final _triggerValue = TextEditingController();
  final _maxActivations = TextEditingController();
  final _rewardType = TextEditingController(text: 'fixed');
  final _referralMinimumTrips = TextEditingController();
  final _compatibleChallenges = TextEditingController();

  String get _programType => switch (_category) {
        'coupon' => _couponTab == 'rules' ? 'activation' : 'coupon',
        'referral' => _referralTab == 'mlm' ? 'referral_commission' : 'referral',
        _ => _category,
      };

  String get _title => switch (_programType) {
        'coupon' => 'Cupones y Promociones',
        'activation' => 'Reglas de Activación',
        'loyalty' => 'Fidelidad',
        'referral' => 'Referidos',
        'referral_commission' => 'Referidos',
        'driver_challenge' => 'Retos',
        _ => 'Beneficios Express',
      };

  String get _newButtonLabel => switch (_programType) {
        'coupon' => 'Nuevo Cupón',
        'activation' => 'Nueva Regla',
        'loyalty' => 'Nueva Campaña',
        'referral' => 'Configurar Programa',
        'referral_commission' => 'Configurar MLM',
        'driver_challenge' => 'Nuevo Reto',
        _ => 'Nuevo',
      };

  String get _editorTitle => switch (_programType) {
        'coupon' => _editingId == null ? 'Crear Nuevo Cupón' : 'Editar Cupón',
        'activation' => _editingId == null ? 'Nueva Regla de Activación' : 'Editar Regla',
        'loyalty' => _editingId == null ? 'Nueva Campaña de Fidelidad' : 'Editar Campaña',
        'referral' => 'Configuración del Programa de Referidos',
        'referral_commission' => 'Configurar Grupos MLM',
        'driver_challenge' => _editingId == null ? 'Crear Nuevo Reto' : 'Editar Reto',
        _ => 'Configurar Beneficio',
      };

  String? _editingId;

  @override
  void initState() {
    super.initState();
    _referralDashboardFuture = Future.value(const <String, dynamic>{});
    _reload();
  }

  @override
  void didUpdateWidget(covariant AdminBenefitsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel != widget.channel || oldWidget.zoneId != widget.zoneId) {
      _clear();
      _reload();
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _description,
      _code,
      _value,
      _maxDiscount,
      _minFare,
      _threshold,
      _leaderPercent,
      _benefitMonths,
      _driverNoCommission,
      _dailyDriverCap,
      _maxPerCustomer,
      _maxTotalRewards,
      _referrerReward,
      _referredReward,
      _maxReferrals,
      _maxTotalUses,
      _usesPerUser,
      _triggerValue,
      _maxActivations,
      _rewardType,
      _referralMinimumTrips,
      _compatibleChallenges,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _reload() {
    _future = () async {
      if (widget.zoneId == null) return <Map<String, dynamic>>[];
      final raw = await supabase.rpc(
        'admin_benefit_program_list',
        params: {
          'p_zone_id': widget.zoneId,
          'p_channel': widget.channel,
          'p_type': _programType,
        },
      );
      return raw is List
          ? raw
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList()
          : <Map<String, dynamic>>[];
    }();
    if (_category == 'referral' && _referralTab == 'referrals') {
      _referralDashboardFuture = _loadReferralDashboard();
    }
  }

  Future<Map<String, dynamic>> _loadReferralDashboard() async {
    if (widget.zoneId == null) return const <String, dynamic>{};
    final raw = await supabase.rpc(
      'admin_driver_referral_dashboard',
      params: {
        'p_zone_id': widget.zoneId,
        'p_channel': widget.channel,
        'p_status': _referralFilter,
      },
    );
    if (raw is! Map) return const <String, dynamic>{};
    return Map<String, dynamic>.from(raw);
  }

  void _clear() {
    _editingId = null;
    for (final controller in [
      _name,
      _description,
      _code,
      _value,
      _maxDiscount,
      _minFare,
      _threshold,
      _leaderPercent,
      _benefitMonths,
      _driverNoCommission,
      _dailyDriverCap,
      _maxPerCustomer,
      _maxTotalRewards,
      _referrerReward,
      _referredReward,
      _maxReferrals,
      _maxTotalUses,
      _usesPerUser,
      _triggerValue,
      _maxActivations,
      _referralMinimumTrips,
      _compatibleChallenges,
    ]) {
      controller.clear();
    }
    _rewardType.text = 'fixed';
    _discount = 'fixed';
    _serviceMode = 'transport';
    _serviceType = 'all';
    _audience = 'passengers';
    _targetAudience = 'all';
    _rewardDestination = 'coupon';
    _referrerType = 'fixed';
    _referredType = 'fixed';
    _referrerDestination = 'wallet';
    _referredDestination = 'wallet';
    _trigger = 'first_trip';
    _period = 'weekly';
    _firstRide = false;
    _sameDayCredits = false;
    _lifetime = true;
    _exclusive = false;
    _enabled = false;
    _startsAt = DateTime.now();
    _endsAt = null;
  }

  void _open(Map<String, dynamic> item) {
    final config = item['config'] is Map
        ? Map<String, dynamic>.from(item['config'] as Map)
        : <String, dynamic>{};
    _editingId = item['id']?.toString();
    _name.text = item['name']?.toString() ?? '';
    _description.text = item['description']?.toString() ?? '';
    _code.text = config['code']?.toString() ?? '';
    _value.text = config['value']?.toString() ?? '';
    _maxDiscount.text = config['max_discount']?.toString() ?? '';
    _minFare.text = config['min_fare']?.toString() ?? '';
    _threshold.text = config['trip_threshold']?.toString() ?? '';
    _leaderPercent.text = config['plan_payment_percent']?.toString() ?? '';
    _benefitMonths.text = config['benefit_months']?.toString() ?? '';
    _driverNoCommission.text = config['driver_no_commission_trips']?.toString() ?? '';
    _dailyDriverCap.text = config['max_credits_per_driver_day']?.toString() ?? '';
    _maxPerCustomer.text = config['max_rewards_per_customer']?.toString() ?? '';
    _maxTotalRewards.text = config['max_total_rewards']?.toString() ?? '';
    _referrerReward.text = config['referrer_reward']?.toString() ?? '';
    _referredReward.text = config['referred_reward']?.toString() ?? '';
    _maxReferrals.text = config['max_referrals_per_user']?.toString() ?? '';
    _maxTotalUses.text = config['max_total_uses']?.toString() ?? '';
    _usesPerUser.text = config['uses_per_user']?.toString() ?? '';
    _triggerValue.text = config['trigger_value']?.toString() ?? '';
    _maxActivations.text = config['max_activations']?.toString() ?? '';
    _rewardType.text = config['reward_type']?.toString() ?? 'fixed';
    _referralMinimumTrips.text = config['min_paid_trips']?.toString() ?? '';
    _compatibleChallenges.text = config['compatible_programs']?.toString() ?? '';
    _discount = config['discount_type']?.toString() ?? 'fixed';
    _serviceMode = config['service_mode']?.toString() ?? 'transport';
    _serviceType = config['service_type']?.toString() ?? 'all';
    _audience = const {'coupon', 'activation', 'loyalty'}.contains(_programType)
        ? 'passengers'
        : config['audience']?.toString() ?? 'passengers';
    _targetAudience = config['target_audience']?.toString() ?? 'all';
    _rewardDestination = _programType == 'activation' || _programType == 'loyalty'
        ? 'coupon'
        : config['reward_destination']?.toString() ?? 'wallet';
    _referrerType = config['referrer_reward_type']?.toString() ?? 'fixed';
    _referredType = config['referred_reward_type']?.toString() ?? 'fixed';
    _referrerDestination = config['referrer_destination']?.toString() ?? 'wallet';
    _referredDestination = config['referred_destination']?.toString() ?? 'wallet';
    _trigger = config['trigger_type']?.toString() ?? 'first_trip';
    _period = config['period']?.toString() ?? 'weekly';
    _firstRide = config['first_ride_only'] == true;
    _sameDayCredits = config['commission_start_same_day'] == true;
    _lifetime = config['lifetime'] != false;
    _exclusive = config['exclusive'] == true;
    _enabled = item['state'] == 'active';
    _startsAt = DateTime.tryParse(item['starts_at']?.toString() ?? '') ?? DateTime.now();
    _endsAt = DateTime.tryParse(item['ends_at']?.toString() ?? '');
  }

  Map<String, dynamic> _buildConfig() {
    final config = <String, dynamic>{
      'service_mode': _serviceMode,
      'service_type': _serviceType,
      'audience': const {'coupon', 'activation', 'loyalty'}.contains(_programType)
          ? 'passengers'
          : _audience,
      'target_audience': _targetAudience,
      'discount_absorber': 'company',
      'value': double.tryParse(_value.text.trim()),
      'reward_type': _rewardType.text.trim(),
      'reward_destination': _programType == 'activation' || _programType == 'loyalty'
          ? 'coupon'
          : _rewardDestination,
      'referrer_reward_type': _referrerType,
      'referred_reward_type': _referredType,
      'referrer_destination': _referrerDestination,
      'referred_destination': _referredDestination,
      'trigger_type': _trigger,
      'trigger_value': _triggerValue.text.trim(),
      'max_activations': int.tryParse(_maxActivations.text.trim()),
      'discount_type': _discount,
      'code': _code.text.trim().toUpperCase(),
      'max_discount': double.tryParse(_maxDiscount.text.trim()),
      'min_fare': double.tryParse(_minFare.text.trim()),
      'first_ride_only': _firstRide,
      'max_total_uses': int.tryParse(_maxTotalUses.text.trim()),
      'uses_per_user': int.tryParse(_usesPerUser.text.trim()),
      'trip_threshold': int.tryParse(_threshold.text.trim()),
      'trip_goal': int.tryParse(_threshold.text.trim()),
      'free_trip_cap': double.tryParse(_maxDiscount.text.trim()),
      'driver_no_commission_trips': int.tryParse(_driverNoCommission.text.trim()),
      'max_credits_per_driver_day': int.tryParse(_dailyDriverCap.text.trim()),
      'commission_start_same_day': _sameDayCredits,
      'max_rewards_per_customer': int.tryParse(_maxPerCustomer.text.trim()),
      'max_total_rewards': int.tryParse(_maxTotalRewards.text.trim()),
      'referrer_reward': double.tryParse(_referrerReward.text.trim()),
      'referred_reward': double.tryParse(_referredReward.text.trim()),
      'min_paid_trips': int.tryParse(_referralMinimumTrips.text.trim()),
      'max_referrals_per_user': int.tryParse(_maxReferrals.text.trim()),
      'plan_payment_percent': double.tryParse(_leaderPercent.text.trim()),
      'benefit_months': int.tryParse(_benefitMonths.text.trim()),
      'lifetime': _lifetime,
      'period': _period,
      'exclusive': _exclusive,
      'compatible_programs': _compatibleChallenges.text
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      // Passenger referrals are intentionally not configured as wallet cash.
      'passenger_referral_reward': 'coupon',
    }..removeWhere((key, value) => value == null || value == '');
    return config;
  }

  Future<void> _save([BuildContext? dialogContext]) async {
    final defaultProgramName = switch (_programType) {
      'referral' => 'Programa de referidos de conductores',
      'referral_commission' => 'MLM de pagos de plan',
      _ => '',
    };
    final programName = _name.text.trim().isNotEmpty
        ? _name.text.trim()
        : (_programType == 'coupon' ? _code.text.trim().toUpperCase() : defaultProgramName);
    if (_saving || widget.zoneId == null || programName.length < 2) {
      return;
    }
    if (_programType == 'coupon' &&
        (_code.text.trim().length < 3 ||
            (double.tryParse(_value.text.trim()) ?? 0) <= 0)) {
      _showMessage('Completa un código y un descuento válido.');
      return;
    }
    if ((_programType == 'loyalty' || _programType == 'driver_challenge') &&
        (int.tryParse(_threshold.text.trim()) ?? 0) <= 0) {
      _showMessage('Indica una meta de viajes válida.');
      return;
    }
    if (_programType == 'activation' &&
        (_trigger != 'first_trip' || _audience != 'passengers' ||
            (double.tryParse(_value.text.trim()) ?? 0) <= 0)) {
      _showMessage('La bienvenida requiere primer viaje, pasajeros y un cupón válido.');
      return;
    }
    if (_programType == 'referral_commission' &&
        (double.tryParse(_leaderPercent.text.trim()) ?? 0) <= 0) {
      _showMessage('Indica el porcentaje del pago de plan.');
      return;
    }

    setState(() => _saving = true);
    try {
      final state = _enabled && const {
        'coupon', 'activation', 'loyalty', 'driver_challenge', 'referral_commission'
      }.contains(_programType) ? 'active' : 'draft';
      await supabase.rpc(
        'admin_benefit_program_save',
        params: {
          'p_id': _editingId,
          'p_zone_id': widget.zoneId,
          'p_channel': widget.channel,
          'p_type': _programType,
          'p_name': programName,
          'p_description': _description.text.trim(),
          'p_config': _buildConfig(),
          'p_state': state,
          'p_starts_at': _startsAt.toUtc().toIso8601String(),
          'p_ends_at': _endsAt?.toUtc().toIso8601String(),
        },
      );
      if (!mounted) return;
      if (dialogContext != null) {
        if (!dialogContext.mounted) return;
        Navigator.of(dialogContext).pop();
      }
      setState(_reload);
      _showMessage(
        _programType == 'referral_commission' && _enabled
            ? 'MLM activo: se acreditará el porcentaje de cada pago de plan confirmado.'
            : state == 'active'
                ? 'Campaña activa. Los beneficios se liquidan al completar un viaje pagado.'
                : 'Guardado como borrador. No aplica descuentos ni premios todavía.',
      );
    } catch (error) {
      _showMessage('No se pudo guardar: ${friendlyError(error)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showEditor() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final screen = MediaQuery.sizeOf(dialogContext);
        final inset = screen.width < 600 ? 8.0 : 24.0;
        final compact = screen.width < 600;
        return Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: inset, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: SizedBox(
            width: screen.width < 808 ? screen.width - inset * 2 : 760,
            height: (screen.height - 24).clamp(240.0, 900.0),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 16, 12, 12),
                  child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_editorTitle, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: _ink)),
                          const SizedBox(height: 4),
                          Text(_editorSubtitle, style: const TextStyle(color: _muted)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 18, compact ? 16 : 24, 20),
                    children: [
                    ..._editorFields(),
                    const SizedBox(height: 8),
                    if (_programType == 'coupon' && _serviceMode == 'delivery')
                      _infoBox('Los cupones de Delivery se guardan como borrador; la liquidación de pedidos tiene un flujo aparte.'),
                    if (_programType == 'referral')
                      _infoBox('Los referidos de conductores por pago de plan se configuran en Grupos MLM.'),
                    if (_programType == 'activation' || _programType == 'loyalty' || _programType == 'driver_challenge')
                      _infoBox('Las recompensas se aplican al completar viajes pagados y se liquidan dentro de la app.'),
                    if (const {'coupon', 'activation', 'loyalty', 'driver_challenge'}.contains(_programType))
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_programType == 'coupon' ? 'Cupón activo' : _programType == 'driver_challenge' ? 'Reto activo' : 'Campaña activa'),
                        subtitle: const Text('Los descuentos y bonos se liquidan al completar un viaje pagado.'),
                        value: _enabled,
                        onChanged: (value) => setState(() => _enabled = value),
                      ),
                    if (_programType == 'referral_commission') ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Programa activo'),
                        subtitle: const Text('La recompensa va a la billetera del conductor que refiere y se genera solo por pagos de plan confirmados.'),
                        value: _enabled,
                        onChanged: (value) => setState(() => _enabled = value),
                      ),
                      _dateFields(),
                    ],
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: EdgeInsets.all(compact ? 10 : 16),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _save(dialogContext),
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Guardando…' : _editorActionLabel),
                    ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String get _editorSubtitle => switch (_programType) {
        'coupon' => 'Configura el descuento, su vigencia y quién puede usarlo.',
        'activation' => 'Define el disparador y la recompensa automática.',
        'loyalty' => 'Cada N viajes pagados, el siguiente viaje del pasajero es gratis.',
        'referral' => 'Programa de referidos de conductores; la recompensa se usa dentro de la app.',
        'referral_commission' => 'El líder recibe un porcentaje de cada pago de plan confirmado.',
        'driver_challenge' => 'Incentivo para conductores por metas de viajes.',
        _ => 'Configura el beneficio.',
      };

  String get _editorActionLabel => switch (_programType) {
        'coupon' => 'Crear Cupón',
        'activation' => 'Crear Regla',
        'loyalty' => 'Crear Campaña',
        'referral_commission' => _enabled ? 'Guardar Configuración MLM' : 'Guardar Borrador',
        'referral' => 'Guardar Configuración',
        'driver_challenge' => 'Crear Reto',
        _ => 'Guardar',
      };

  List<Widget> _editorFields() {
    final fields = <Widget>[
      if (_programType != 'coupon')
        _textField('Nombre *', _name, hint: 'Ej.: Viaje 6 gratis'),
      if (_programType == 'coupon')
        _textField('Código *', _code, hint: 'BIENVENIDO20'),
      _textField(
        'Descripción${_programType == 'coupon' ? '' : ' (opcional)'}',
        _description,
        hint: _programType == 'coupon' ? 'Describe el cupón…' : 'Texto interno para tu equipo',
        maxLines: 3,
      ),
    ];

    switch (_programType) {
      case 'coupon':
        fields.addAll([
          _twoColumns([
            _dropdown('Tipo de descuento', _discount, const {'fixed': 'Monto fijo', 'percent': 'Porcentaje'}, (value) => setState(() => _discount = value)),
            _textField(_discount == 'percent' ? 'Porcentaje *' : 'Monto (Bs) *', _value, keyboard: const TextInputType.numberWithOptions(decimal: true)),
          ]),
          _twoColumns([
            _textField('Máximo de descuento (Bs)', _maxDiscount, hint: 'Sin límite', keyboard: const TextInputType.numberWithOptions(decimal: true)),
            _segmentedField('Servicio', _serviceMode, const {'transport': 'Transporte', 'delivery': 'Delivery'}, (value) => setState(() => _serviceMode = value)),
          ]),
          _dropdown('Tipos de servicio', _serviceType, const {'all': 'Todos los servicios', 'economy': 'Económico', 'comfort': 'Confort', 'moto': 'Moto', 'motocar': 'Motocar'}, (value) => setState(() => _serviceType = value)),
          _textField('Monto mínimo de viaje (Bs)', _minFare, hint: 'Sin mínimo', keyboard: const TextInputType.numberWithOptions(decimal: true)),
          _dropdown('Audiencia', 'passengers', const {'passengers': 'Pasajeros'}, (_) => setState(() => _audience = 'passengers')),
          _twoColumns([
            _dropdown('Audiencia objetivo', _targetAudience, const {'all': 'Todos los usuarios', 'new': 'Usuarios nuevos', 'returning': 'Usuarios frecuentes'}, (value) => setState(() => _targetAudience = value)),
            _dropdown('Quién cubre el descuento', 'company', const {'company': 'Express · crédito al conductor'}, (_) {}),
          ]),
          _twoColumns([
            _textField('Usos totales máximos', _maxTotalUses, hint: 'Ilimitado', keyboard: TextInputType.number),
            _textField('Usos por usuario', _usesPerUser, hint: '1', keyboard: TextInputType.number),
          ]),
          _dateFields(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Solo primer viaje'),
            value: _firstRide,
            onChanged: (value) => setState(() => _firstRide = value),
          ),
        ]);
      case 'activation':
        fields.addAll([
          _twoColumns([
            _dropdown('Tipo de disparador', _trigger, const {'first_trip': 'Primer viaje', 'paid_trips': 'Viajes pagados', 'first_delivery': 'Primer delivery'}, (value) => setState(() => _trigger = value)),
            _textField('Valor (opcional)', _triggerValue, hint: 'Opcional', keyboard: TextInputType.number),
          ]),
          _twoColumns([
            _dropdown('Tipo de recompensa', _rewardType.text, const {'fixed': 'Monto fijo (Bs)', 'percent': 'Porcentaje', 'coupon': 'Cupón de viaje'}, (value) => setState(() => _rewardType.text = value)),
            _textField('Valor de recompensa', _value, keyboard: const TextInputType.numberWithOptions(decimal: true)),
          ]),
          _twoColumns([
            _dropdown('Destino de recompensa', 'coupon', const {'coupon': 'Cupón de viaje'}, (_) {}),
            _dropdown('Audiencia objetivo', _audience, const {'passengers': 'Pasajeros'}, (_) => setState(() => _audience = 'passengers')),
          ]),
          _textField('Máximo de activaciones (opcional)', _maxActivations, hint: 'Sin límite', keyboard: TextInputType.number),
          _dateFields(),
        ]);
      case 'loyalty':
        fields.addAll([
          _twoColumns([
            _textField('Umbral N (viajes pagados)', _threshold, hint: '5', keyboard: TextInputType.number),
            _textField('Tope del viaje gratis (Bs)', _maxDiscount, hint: 'Sin límite', keyboard: const TextInputType.numberWithOptions(decimal: true)),
          ]),
          _twoColumns([
            _textField('Máx. premios por cliente', _maxPerCustomer, hint: 'Sin límite', keyboard: TextInputType.number),
            _textField('Máx. premios totales', _maxTotalRewards, hint: 'Sin límite', keyboard: TextInputType.number),
          ]),
          _infoBox('Cada N viajes pagados, el pasajero recibe un cupón para su próximo viaje gratis. El valor cubierto se acredita a la billetera interna del conductor.'),
          _dateFields(),
        ]);
      case 'referral':
        fields.addAll([
          const Text('Recompensa para quien refiere', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _twoColumns([
            _dropdown('Tipo de recompensa', _rewardType.text, const {'fixed': 'Monto fijo', 'percent': 'Porcentaje', 'coupon': 'Cupón'}, (value) => setState(() => _rewardType.text = value)),
            _textField('Valor (Bs)', _referrerReward, keyboard: const TextInputType.numberWithOptions(decimal: true)),
          ]),
          _dropdown('Destino', _rewardDestination, const {'wallet': 'Billetera interna', 'coupon': 'Cupón'}, (value) => setState(() => _rewardDestination = value)),
          const SizedBox(height: 14),
          const Text('Recompensa para el conductor referido', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _twoColumns([
            _dropdown('Tipo de recompensa', _rewardType.text, const {'fixed': 'Monto fijo', 'percent': 'Porcentaje', 'coupon': 'Cupón'}, (value) => setState(() => _rewardType.text = value)),
            _textField('Valor (Bs)', _referredReward, keyboard: const TextInputType.numberWithOptions(decimal: true)),
          ]),
          _twoColumns([
            _textField('Viajes mínimos para activar', _referralMinimumTrips, keyboard: TextInputType.number),
            _textField('Máximo de referidos por usuario', _maxReferrals, hint: 'Sin límite', keyboard: TextInputType.number),
          ]),
          _infoBox('Este programa es para conductores. A los pasajeros se les asignan cupones, no saldo retirable.'),
        ]);
      case 'referral_commission':
        fields.addAll([
          _textField('Porcentaje del pago de plan', _leaderPercent, hint: 'Ej.: 1', keyboard: const TextInputType.numberWithOptions(decimal: true)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Beneficio de por vida'),
            value: _lifetime,
            onChanged: (value) => setState(() => _lifetime = value),
          ),
          if (!_lifetime) _textField('Vigencia del beneficio (meses)', _benefitMonths, keyboard: TextInputType.number),
          _infoBox('El crédito va a la billetera interna del conductor que refirió, únicamente por cada pago de plan confirmado en Bolivia.'),
        ]);
      case 'driver_challenge':
        fields.addAll([
          _twoColumns([
            _textField('Meta (número de viajes) *', _threshold, hint: '10', keyboard: TextInputType.number),
            _dropdown('Periodo', _period, const {'daily': 'Diario', 'weekly': 'Semanal', 'monthly': 'Mensual', 'custom': 'Personalizado'}, (value) => setState(() => _period = value)),
          ]),
          _dateFields(),
          _twoColumns([
            _dropdown('Tipo de recompensa', 'wallet', const {'wallet': 'Bono en billetera interna'}, (_) {}),
            _textField('Monto del bono (Bs)', _value, keyboard: const TextInputType.numberWithOptions(decimal: true)),
          ]),
          _infoBox('Zona: ${widget.zoneId ?? 'Selecciona una zona'}'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reto exclusivo (el conductor no puede inscribirse a otros retos)'),
            value: _exclusive,
            onChanged: (value) => setState(() => _exclusive = value),
          ),
          _textField('Compatible con (opcional)', _compatibleChallenges, hint: 'Nombres separados por coma'),
        ]);
    }
    return fields;
  }

  Widget _dateFields() => _twoColumns([
        _dateButton('Fecha de inicio *', _startsAt, isEnd: false),
        _dateButton('Fecha de fin (opcional)', _endsAt, isEnd: true),
      ]);

  Widget _dateButton(String label, DateTime? value, {required bool isEnd}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            side: const BorderSide(color: _line),
          ),
          onPressed: () async {
            final selected = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (selected == null || !mounted) return;
            setState(() {
              if (isEnd) {
                _endsAt = selected;
              } else {
                _startsAt = selected;
              }
            });
          },
          child: Row(children: [
            Expanded(child: Text('$label\n${value == null ? 'Sin fecha' : _formatDate(value)}', style: const TextStyle(color: _ink))),
            const Icon(Icons.calendar_today_outlined, size: 18),
          ]),
        ),
      );

  Widget _textField(
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboard,
    int maxLines = 1,
    bool enabled = true,
  }) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboard,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );

  Widget _dropdown(
    String label,
    String value,
    Map<String, String> items,
    ValueChanged<String> onChanged,
  ) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          initialValue: items.containsKey(value) ? value : items.keys.first,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: items.entries
              .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
              .toList(),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      );

  Widget _segmentedField(
    String label,
    String value,
    Map<String, String> items,
    ValueChanged<String> onChanged,
  ) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Wrap(
            spacing: 8,
            children: items.entries
                .map((entry) => ChoiceChip(
                      label: Text(entry.value),
                      selected: value == entry.key,
                      onSelected: (_) => onChanged(entry.key),
                    ))
                .toList(),
          ),
        ),
      );

  Widget _twoColumns(List<Widget> children) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 560 || children.length != 2) {
            return Column(children: children);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: children[0]),
            const SizedBox(width: 12),
            Expanded(child: children[1]),
          ]);
        },
      );

  Widget _infoBox(String text) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E8),
          border: Border.all(color: const Color(0xFFFED7AA)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: const TextStyle(color: Color(0xFF9A4D00))),
      );

  @override
  Widget build(BuildContext context) {
    if (widget.zoneId == null) {
      return const Center(child: Text('Selecciona una zona para administrar beneficios.'));
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('No se pudieron cargar los programas: ${friendlyError(snapshot.error)}'));
        }
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        final visibleRows = rows.where(_matchesFilter).toList();
        final inlineReferralSettings = _category == 'referral' && _referralTab != 'referrals';
        if (inlineReferralSettings && rows.isNotEmpty && _editingId != rows.first['id']?.toString()) {
          _open(rows.first);
        }
        final compact = MediaQuery.sizeOf(context).width < 720;
        return ListView(
          padding: EdgeInsets.all(compact ? 12 : 22),
          children: [
            Row(children: [
              const Icon(Icons.card_giftcard_outlined, color: _adminBlue, size: 29),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: _ink)),
                Text(_subtitle, style: const TextStyle(color: _muted)),
              ])),
            ]),
            const SizedBox(height: 18),
            _categoryButtons(),
            if (_category == 'coupon') ...[
              const SizedBox(height: 10),
              _subTabs({'coupons': 'Cupones', 'rules': 'Reglas de Activación'}, _couponTab, (value) {
                setState(() { _clear(); _couponTab = value; _filter = 'all'; _reload(); });
              }),
            ],
            if (_category == 'referral') ...[
              const SizedBox(height: 10),
              _subTabs({'program': 'Programa', 'referrals': 'Referidos', 'mlm': 'Grupos MLM'}, _referralTab, (value) {
                setState(() { _clear(); _referralTab = value; _filter = 'all'; _reload(); });
              }),
            ],
            const SizedBox(height: 16),
            if (inlineReferralSettings)
              _referralTab == 'mlm' ? _mlmSettings() : _referralSettings()
            else ...[
            if (_category == 'referral' && _referralTab == 'referrals')
              _referralsPanel()
            else ...[
              _metrics(rows),
              const SizedBox(height: 18),
              _programTable(visibleRows),
            ],
            ],
          ],
        );
      },
    );
  }

  String get _subtitle => switch (_programType) {
        'coupon' => 'Crea y administra cupones de descuento para tus clientes.',
        'activation' => 'Configura recompensas automáticas basadas en acciones de usuarios.',
        'loyalty' => 'Premia a tus pasajeros frecuentes con viajes gratis.',
        'referral' => 'Configura y administra el programa de referidos de conductores.',
        'referral_commission' => 'Configura y administra el programa de referidos de tu empresa.',
        'driver_challenge' => 'Crea y administra retos para motivar a tus conductores.',
        _ => 'Administra tus programas de beneficios.',
      };

  Widget _categoryButtons() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: _categories.map((item) {
          final selected = item.$1 == _category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: selected ? const Color(0xFFEAF2FF) : Colors.white,
                foregroundColor: selected ? _adminBlue : _ink,
                side: BorderSide(color: selected ? _adminBlue : _line),
              ),
              onPressed: () => setState(() {
                _clear();
                _category = item.$1;
                _filter = 'all';
                _reload();
              }),
              icon: Icon(item.$3, size: 18),
              label: Text(item.$2),
            ),
          );
        }).toList()),
      );

  Widget _subTabs(Map<String, String> labels, String selected, ValueChanged<String> onChanged) => Wrap(
        spacing: 6,
        children: labels.entries.map((entry) => ChoiceChip(
          label: Text(entry.value),
          selected: selected == entry.key,
          onSelected: (_) => onChanged(entry.key),
        )).toList(),
      );

  Widget _metrics(List<Map<String, dynamic>> rows) {
    final active = rows.where((row) => row['state'] == 'active').length;
    final drafts = rows.where((row) => row['state'] == 'draft').length;
    final items = switch (_programType) {
      'coupon' => <(String, String, IconData)>[
          ('Total Cupones', '${rows.length}', Icons.local_offer_outlined),
          ('Activos', '$active', Icons.confirmation_num_outlined),
          ('Canjes Totales', '—', Icons.people_outline),
          ('Descuento Total', '—', Icons.payments_outlined),
        ],
      'activation' => <(String, String, IconData)>[
          ('Total Reglas', '${rows.length}', Icons.bolt_outlined),
          ('Reglas Activas', '$active', Icons.track_changes_outlined),
          ('Total Activaciones', '—', Icons.trending_up_rounded),
        ],
      'loyalty' => <(String, String, IconData)>[
          ('Total Campañas', '${rows.length}', Icons.card_giftcard_outlined),
          ('Clientes Participando', '—', Icons.people_outline),
          ('Premios Otorgados', '—', Icons.emoji_events_outlined),
          ('Créditos a Conductores', '—', Icons.directions_car_outlined),
        ],
      'referral' || 'referral_commission' => <(String, String, IconData)>[
          ('Total Referidos', '—', Icons.people_alt_outlined),
          ('Pendientes', '—', Icons.schedule_outlined),
          ('Activados', '—', Icons.check_circle_outline),
          ('Tasa Conversión', '—', Icons.trending_up_rounded),
        ],
      'driver_challenge' => <(String, String, IconData)>[
          ('Total Retos', '${rows.length}', Icons.flag_outlined),
          ('Inscripciones del periodo', '—', Icons.people_outline),
          ('Completados', '—', Icons.emoji_events_outlined),
          ('Tasa de Éxito', '—', Icons.trending_up_rounded),
        ],
      _ => <(String, String, IconData)>[],
    };
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map((item) => SizedBox(
        width: 218,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(side: const BorderSide(color: _line), borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(item.$1, style: const TextStyle(color: _muted, fontSize: 12))), Icon(item.$3, size: 18, color: _adminBlue)]),
              const SizedBox(height: 12),
              Text(item.$2, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: _ink)),
              const SizedBox(height: 3),
              Text(_programType == 'referral' || _programType == 'referral_commission' ? 'Solo conductores' : '$drafts borradores · $active activas', style: const TextStyle(fontSize: 11, color: _muted)),
            ]),
          ),
        ),
      )).toList(),
    );
  }

  List<String> get _tableHeaders => switch (_programType) {
        'coupon' => const ['Código', 'Módulo', 'Tipo', 'Valor', 'Usos', 'Vigencia', 'Audiencia', 'Estado', 'Acciones'],
        'activation' => const ['Nombre', 'Disparador', 'Recompensa', 'Audiencia', 'Activaciones', 'Estado', 'Acciones'],
        'loyalty' => const ['Nombre', 'Umbral', 'Premio conductor', 'Participando', 'Otorgados', 'Cobrados', 'Créditos', 'Estado', 'Acciones'],
        'referral' => const ['Programa', 'Premio quien refiere', 'Premio referido', 'Condición', 'Estado', 'Acciones'],
        'referral_commission' => const ['Programa MLM', 'Porcentaje del plan', 'Vigencia', 'Estado', 'Acciones'],
        'driver_challenge' => const ['Nombre', 'Meta', 'Período', 'Recompensa', 'Inscritos', 'Completados', 'Estado', 'Acciones'],
        _ => const ['Nombre', 'Estado', 'Acciones'],
      };

  List<String> _tableCells(Map<String, dynamic> row) {
    final config = row['config'] is Map
        ? Map<String, dynamic>.from(row['config'] as Map)
        : <String, dynamic>{};
    final state = _stateLabel(row['state']?.toString() ?? 'draft');
    final date = DateTime.tryParse(row['starts_at']?.toString() ?? '');
    final until = DateTime.tryParse(row['ends_at']?.toString() ?? '');
    final validity = '${date == null ? '—' : _formatDate(date)}${until == null ? '' : ' – ${_formatDate(until)}'}';
    final actions = 'Editar ···';
    return switch (_programType) {
      'coupon' => [
          config['code']?.toString() ?? row['name']?.toString() ?? '—',
          config['service_mode']?.toString() == 'delivery' ? 'Delivery' : 'Transporte',
          config['discount_type']?.toString() == 'percent' ? 'Porcentaje' : 'Monto fijo',
          '${config['value'] ?? '—'}${config['discount_type'] == 'percent' ? '%' : ''}',
          '${config['uses'] ?? 0}/${config['max_total_uses'] ?? '∞'}',
          validity,
          config['audience']?.toString() ?? 'Pasajeros', state, actions,
        ],
      'activation' => [
          row['name']?.toString() ?? '—', config['trigger_type']?.toString() ?? 'Primer viaje',
          '${config['reward_type'] ?? 'Monto fijo'} ${config['value'] ?? '—'}',
          config['audience']?.toString() ?? 'Clientes', '${config['activations'] ?? 0}', state, actions,
        ],
      'loyalty' => [
          row['name']?.toString() ?? '—', '${config['trip_threshold'] ?? '—'} viajes',
          '${config['driver_no_commission_trips'] ?? 0} viajes sin comisión',
          '${config['participants'] ?? 0}', '${config['awards'] ?? 0}',
          '${config['redeemed'] ?? 0}', '${config['max_credits_per_driver_day'] ?? '—'}', state, actions,
        ],
      'referral' => [
          row['name']?.toString() ?? 'Referidos de conductores',
          config['referrer_reward']?.toString() ?? '—', config['referred_reward']?.toString() ?? '—',
          '${config['min_paid_trips'] ?? 0} viajes pagados', state, actions,
        ],
      'referral_commission' => [
          row['name']?.toString() ?? 'MLM de pagos de plan',
          '${config['plan_payment_percent'] ?? '—'}%',
          config['lifetime'] == true ? 'De por vida' : '${config['benefit_months'] ?? '—'} meses', state, actions,
        ],
      'driver_challenge' => [
          row['name']?.toString() ?? '—', '${config['trip_goal'] ?? '—'} viajes',
          config['period']?.toString() ?? '—', '${config['reward_type'] ?? 'Billetera'} ${config['value'] ?? '—'}',
          '${config['participants'] ?? 0}', '${config['completed'] ?? 0}', state, actions,
        ],
      _ => [row['name']?.toString() ?? '—', state, actions],
    };
  }

  Widget _programTable(List<Map<String, dynamic>> rows) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 720 ? 10 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            LayoutBuilder(builder: (context, constraints) {
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(_listTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _ink)),
                Text(_listSubtitle, style: const TextStyle(color: _muted, fontSize: 12)),
                ],
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: constraints.maxWidth < 420 ? constraints.maxWidth : 160,
                    child: DropdownButtonFormField<String>(
                      initialValue: _filter,
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Todas')),
                        DropdownMenuItem(value: 'active', child: Text('Activas')),
                        DropdownMenuItem(value: 'scheduled', child: Text('Programadas')),
                        DropdownMenuItem(value: 'closed', child: Text('Terminadas')),
                        DropdownMenuItem(value: 'draft', child: Text('Inactivas')),
                      ],
                      onChanged: (value) => setState(() => _filter = value ?? 'all'),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () { _clear(); _showEditor(); },
                    icon: const Icon(Icons.add),
                    label: Text(_newButtonLabel),
                  ),
                ],
              );
              if (constraints.maxWidth < 700) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [title, const SizedBox(height: 12), actions],
                );
              }
              return Row(children: [Expanded(child: title), actions]);
            }),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 42),
                child: Center(child: Column(children: [
                  Icon(_emptyIcon, size: 34, color: const Color(0xFF98A2B3)),
                  const SizedBox(height: 8),
                  Text(_emptyMessage, style: const TextStyle(fontWeight: FontWeight.w700, color: _ink)),
                  const SizedBox(height: 4),
                  const Text('Los elementos aparecerán aquí cuando se creen.', style: TextStyle(color: _muted)),
                ])),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: _tableHeaders.map((label) => DataColumn(label: Text(label))).toList(),
                  rows: rows.map((row) => DataRow(
                    cells: _tableCells(row).asMap().entries.map((cell) => DataCell(
                      Text(cell.value, style: TextStyle(
                        fontWeight: cell.key == 0 ? FontWeight.w700 : FontWeight.normal,
                        color: cell.key == _tableHeaders.length - 2 && row['state'] == 'active' ? Colors.green.shade700 : _ink,
                      )),
                      onTap: cell.key == _tableHeaders.length - 1 ? () {
                        _open(row);
                        _showEditor();
                      } : null,
                    )).toList(),
                  )).toList(),
                ),
              ),
          ]),
        ),
      );

  Widget _referralSettings() => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(side: const BorderSide(color: _line), borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Programa de referidos de conductores', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'La comisión vigente se calcula como un porcentaje de cada pago de plan aprobado por el conductor referido. No depende de viajes mínimos ni genera un bono fijo por viaje.',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 18),
            _infoBox('Configura el porcentaje, la vigencia y la activación en Grupos MLM. La comisión se acredita en la billetera interna del conductor que refirió.'),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => setState(() {
                  _clear();
                  _referralTab = 'mlm';
                  _filter = 'all';
                  _reload();
                }),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('Configurar comisión del plan'),
              ),
            ),
          ]),
        ),
      );

  Widget _mlmSettings() => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(side: const BorderSide(color: _line), borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Grupos MLM — Comisión por pagos de plan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const Text('El conductor que refiere recibe un porcentaje de cada pago de plan confirmado por el conductor referido.', style: TextStyle(color: _muted)),
            const SizedBox(height: 20),
            _twoColumns([
              _textField('Porcentaje del pago de plan', _leaderPercent, hint: 'Ej.: 1', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              if (!_lifetime) _textField('Vigencia del beneficio (meses)', _benefitMonths, keyboard: TextInputType.number),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Beneficio de por vida'),
              subtitle: const Text('Si está activo, el beneficio no vence mientras el referido siga pagando planes.'),
              value: _lifetime,
              onChanged: (value) => setState(() => _lifetime = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Programa activo'),
              subtitle: const Text('Aplica a conductores de Bolivia y acredita la comisión en la billetera interna.'),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            _dateFields(),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: const Text('Guardar configuración MLM')),
            ),
          ]),
        ),
      );

  Widget _referralsPanel() => FutureBuilder<Map<String, dynamic>>(
        future: _referralDashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(36),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text('No se pudo cargar el historial de referidos: ${friendlyError(snapshot.error)}'),
              ),
            );
          }
          final dashboard = snapshot.data ?? const <String, dynamic>{};
          final stats = dashboard['stats'] is Map
              ? Map<String, dynamic>.from(dashboard['stats'] as Map)
              : const <String, dynamic>{};
          final referrals = dashboard['referrals'] is List
              ? (dashboard['referrals'] as List)
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList()
              : <Map<String, dynamic>>[];
          final total = _intValue(stats['total']);
          final pending = _intValue(stats['pending']);
          final activated = _intValue(stats['activated']);
          final conversion = _numberValue(stats['conversion_percent']);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 12, runSpacing: 12, children: [
              _referralMetric('Total Referidos', '$total', Icons.people_alt_outlined, _adminBlue),
              _referralMetric('Pendientes', '$pending', Icons.schedule_outlined, const Color(0xFFB54708)),
              _referralMetric('Activados', '$activated', Icons.check_circle_outline, const Color(0xFF027A48)),
              _referralMetric('Tasa Conversión', '${conversion.toStringAsFixed(conversion % 1 == 0 ? 0 : 1)}%', Icons.trending_up_rounded, _adminBlue),
            ]),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(side: const BorderSide(color: _line), borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(spacing: 16, runSpacing: 12, children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _referralFilter,
                      decoration: const InputDecoration(labelText: 'Estado', isDense: true, border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Todos')),
                        DropdownMenuItem(value: 'pending', child: Text('Pendientes')),
                        DropdownMenuItem(value: 'qualified', child: Text('Activados')),
                        DropdownMenuItem(value: 'reward_review', child: Text('En revisión')),
                        DropdownMenuItem(value: 'closed', child: Text('Cerrados')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _referralFilter = value;
                          _referralDashboardFuture = _loadReferralDashboard();
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _referralTypeFilter,
                      decoration: const InputDecoration(labelText: 'Tipo de referidor', isDense: true, border: OutlineInputBorder()),
                      items: const [DropdownMenuItem(value: 'all', child: Text('Todos')), DropdownMenuItem(value: 'driver', child: Text('Conductor'))],
                      onChanged: (value) => setState(() => _referralTypeFilter = value ?? 'all'),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            _referralHistory(referrals),
          ]);
        },
      );

  int _intValue(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  double _numberValue(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  Widget _referralMetric(String title, String value, IconData icon, Color color) => SizedBox(
        width: 218,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(side: const BorderSide(color: _line), borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(title, style: const TextStyle(color: _muted, fontSize: 12))), Icon(icon, size: 19, color: color)]),
              const SizedBox(height: 12),
              Text(value, style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: color)),
            ]),
          ),
        ),
      );

  Widget _referralHistory(List<Map<String, dynamic>> referrals) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(side: const BorderSide(color: _line), borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Lista de Referidos', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _ink)),
            const Text('Historial de conductores y comisiones acreditadas por pagos de plan.', style: TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 14),
            if (referrals.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(child: Column(children: [
                  Icon(Icons.card_giftcard_outlined, size: 38, color: _muted),
                  SizedBox(height: 10),
                  Text('No hay referidos registrados', style: TextStyle(fontWeight: FontWeight.w800)),
                  SizedBox(height: 5),
                  Text('Los vínculos aparecerán cuando un conductor use un código de referido.', style: TextStyle(color: _muted), textAlign: TextAlign.center),
                ])),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Referidor')),
                    DataColumn(label: Text('Código')),
                    DataColumn(label: Text('Conductor referido')),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Pagos de plan')),
                    DataColumn(label: Text('Comisión acreditada')),
                    DataColumn(label: Text('Último pago')),
                  ],
                  rows: referrals.where((row) => _referralTypeFilter == 'all' || _referralTypeFilter == 'driver').map((row) {
                    final state = row['state']?.toString() ?? 'pending';
                    final status = switch (state) {
                      'qualified' => 'Activado',
                      'reward_review' => 'En revisión',
                      'closed' => 'Cerrado',
                      _ => 'Pendiente',
                    };
                    final lastPayment = DateTime.tryParse(row['last_payment_at']?.toString() ?? '');
                    return DataRow(cells: [
                      DataCell(Text(row['referrer_name']?.toString() ?? '—')),
                      DataCell(Text(row['referral_code']?.toString() ?? '—')),
                      DataCell(Text(row['referred_name']?.toString() ?? '—')),
                      DataCell(Text(status)),
                      DataCell(Text('${_intValue(row['plan_payment_count'])}')),
                      DataCell(Text('Bs ${_numberValue(row['commission_total']).toStringAsFixed(2)}')),
                      DataCell(Text(lastPayment == null ? '—' : _formatDate(lastPayment))),
                    ]);
                  }).toList(),
                ),
              ),
          ]),
        ),
      );

  bool _matchesFilter(Map<String, dynamic> row) {
    if (_filter == 'all') return true;
    final state = row['state']?.toString() ?? 'draft';
    if (_filter == 'scheduled') {
      final start = DateTime.tryParse(row['starts_at']?.toString() ?? '');
      return state == 'active' && start != null && start.isAfter(DateTime.now());
    }
    if (_filter == 'closed') return state == 'closed';
    if (_filter == 'draft') return state == 'draft' || state == 'paused';
    return state == _filter;
  }

  String get _listTitle => switch (_programType) {
        'coupon' => 'Lista de Cupones',
        'activation' => 'Reglas de Activación',
        'loyalty' => 'Campañas de Fidelidad',
        'referral' => 'Programa de Referidos de Conductores',
        'referral_commission' => 'Configuración MLM',
        'driver_challenge' => 'Lista de Retos',
        _ => 'Programas',
      };

  String get _listSubtitle => switch (_programType) {
        'coupon' => 'Administra los cupones de descuento de tu empresa.',
        'activation' => 'Recompensas automáticas basadas en acciones de usuarios.',
        'loyalty' => 'Premia a tus pasajeros frecuentes y conductores.',
        'referral' => 'Referidos de conductores y sus recompensas dentro de Express.',
        'referral_commission' => 'Porcentaje de cada pago de plan confirmado en Bolivia.',
        'driver_challenge' => 'Administra las metas y recompensas para conductores.',
        _ => '',
      };

  String get _emptyMessage => switch (_programType) {
        'coupon' => 'No hay cupones configurados.',
        'activation' => 'No hay reglas de activación configuradas.',
        'loyalty' => 'No hay campañas de fidelidad.',
        'referral' => 'Configura el programa de referidos para conductores.',
        'referral_commission' => 'No hay configuración MLM guardada.',
        'driver_challenge' => 'No hay retos configurados.',
        _ => 'No hay programas todavía.',
      };

  IconData get _emptyIcon => switch (_programType) {
        'coupon' => Icons.local_offer_outlined,
        'activation' => Icons.bolt_outlined,
        'loyalty' => Icons.loyalty_outlined,
        'referral' || 'referral_commission' => Icons.people_alt_outlined,
        'driver_challenge' => Icons.flag_outlined,
        _ => Icons.card_giftcard_outlined,
      };

  String _formatDate(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
