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
    this.countryCode,
  });

  final String channel;
  final String? zoneId;
  // Solo para mostrar el nombre de la zona en el formulario (no el UUID).
  final String? countryCode;

  @override
  State<AdminBenefitsPage> createState() => _AdminBenefitsPageState();
}

class _AdminBenefitsPageState extends State<AdminBenefitsPage> {
  late Future<List<Map<String, dynamic>>> _future;
  late Future<Map<String, dynamic>> _referralDashboardFuture;
  String _category = 'coupon';
  String _couponTab = 'coupons';
  // Start with program configuration, followed by referral history and MLM.
  String _referralTab = 'program';
  String _discount = 'fixed';
  String _filter = 'all';
  String _referralFilter = 'all';
  String _referralTypeFilter = 'all';
  String _serviceMode = 'transport';
  String _serviceType = 'all';
  String _discountAbsorber = 'company';
  String _challengeRewardType = 'commission_free';
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
  bool _allChallengeZones = true;
  bool _enabled = false;
  bool _saving = false;
  final Set<String> _compatibleChallengeIds = <String>{};
  List<Map<String, dynamic>> _challengeRows = <Map<String, dynamic>>[];
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
  final _challengeFreeTrips = TextEditingController();

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
  String? _zoneLabel;
  String get _currencyLabel => widget.countryCode == 'BO' ? 'BOB' : 'CLP';

  @override
  void initState() {
    super.initState();
    _referralDashboardFuture = Future.value(const <String, dynamic>{});
    _reload();
    _loadZoneLabel();
  }

  @override
  void didUpdateWidget(covariant AdminBenefitsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel != widget.channel || oldWidget.zoneId != widget.zoneId) {
      _clear();
      _reload();
    }
    if (oldWidget.zoneId != widget.zoneId ||
        oldWidget.countryCode != widget.countryCode) {
      _loadZoneLabel();
    }
  }

  /// Nombre y ciudad de la zona para el formulario. Si falla, se muestra un
  /// texto genérico; nunca el identificador técnico.
  Future<void> _loadZoneLabel() async {
    final zoneId = widget.zoneId;
    final country = widget.countryCode;
    String? label;
    if (zoneId != null && country != null) {
      try {
        final raw = await supabase.rpc(
          'admin_zone_list_for_country',
          params: {'p_country_code': country},
        );
        if (raw is List) {
          for (final row in raw.whereType<Map>()) {
            if (row['id']?.toString() == zoneId) {
              final name = (row['name'] ?? '').toString().trim();
              final city = (row['city'] ?? '').toString().trim();
              if (name.isNotEmpty) {
                label = city.isEmpty ? name : '$name · $city';
              }
              break;
            }
          }
        }
      } catch (_) {
        label = null;
      }
    }
    if (mounted) setState(() => _zoneLabel = label);
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
      _challengeFreeTrips,
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
    _compatibleChallengeIds.clear();
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
      _challengeFreeTrips,
    ]) {
      controller.clear();
    }
    _rewardType.text = 'fixed';
    _discount = 'fixed';
    _serviceMode = 'transport';
    _serviceType = 'all';
    _discountAbsorber = 'company';
    _challengeRewardType = 'commission_free';
    _audience = 'passengers';
    _targetAudience = 'all';
    _rewardDestination = _programType == 'activation' ? 'wallet' : 'coupon';
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
    _allChallengeZones = true;
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
    _leaderPercent.text = config['company_commission_percent']?.toString() ??
        config['plan_payment_percent']?.toString() ?? '';
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
    final compatible = config['compatible_programs'];
    final compatibleValues = compatible is List
        ? compatible.map((value) => value.toString()).toList()
        : compatible == null
            ? <String>[]
            : compatible.toString().split(',').map((value) => value.trim()).toList();
    _compatibleChallengeIds
      ..clear()
      ..addAll(compatibleValues.map((value) {
        final match = _challengeRows.where((row) =>
            row['id']?.toString() == value || row['name']?.toString() == value);
        return match.isEmpty ? value : match.first['id'].toString();
      }));
    _discount = config['discount_type']?.toString() ?? 'fixed';
    _serviceMode = config['service_mode']?.toString() ?? 'transport';
    _serviceType = config['service_type']?.toString() ?? 'all';
    _discountAbsorber = config['discount_absorber']?.toString() ?? 'company';
    _challengeFreeTrips.text = config['commission_free_trips']?.toString() ?? '';
    _challengeRewardType = config['reward_type']?.toString() ??
        (config.containsKey('commission_free_trips') ? 'commission_free' : 'wallet');
    _audience = _programType == 'driver_challenge'
        ? (const {'drivers', 'all'}.contains(config['audience']) ? config['audience'].toString() : 'drivers')
        : const {'coupon', 'activation', 'loyalty'}.contains(_programType)
            ? 'passengers'
            : config['audience']?.toString() ?? 'passengers';
    _targetAudience = config['target_audience']?.toString() ?? 'all';
    _rewardDestination = config['reward_destination']?.toString() ??
        (_programType == 'activation' ? 'wallet' : 'coupon');
    _referrerType = 'fixed';
    _referredType = 'fixed';
    _referrerDestination = 'wallet';
    _referredDestination = 'wallet';
    _trigger = config['trigger_type']?.toString() ?? 'first_trip';
    _period = config['period']?.toString() ?? 'weekly';
    _firstRide = config['first_ride_only'] == true;
    _sameDayCredits = config['commission_start_same_day'] == true;
    _lifetime = config['lifetime'] != false;
    _exclusive = config['exclusive'] == true;
    _allChallengeZones = config['zone_scope'] == 'all';
    _enabled = item['state'] == 'active';
    _startsAt = DateTime.tryParse(item['starts_at']?.toString() ?? '') ?? DateTime.now();
    _endsAt = DateTime.tryParse(item['ends_at']?.toString() ?? '');
  }

  Map<String, dynamic> _buildConfig() {
    final config = <String, dynamic>{
      'service_mode': _serviceMode,
      'service_type': _serviceType,
      'audience': _programType == 'driver_challenge'
          ? (_audience == 'all' ? 'all' : 'drivers')
          : const {'coupon', 'activation', 'loyalty'}.contains(_programType)
              ? (_programType == 'coupon' && _serviceMode == 'delivery' ? 'clients' : 'passengers')
              : _audience,
      'target_audience': _targetAudience,
      'discount_absorber': _discountAbsorber,
      'value': _programType == 'driver_challenge' && _challengeRewardType == 'commission_free'
          ? int.tryParse(_challengeFreeTrips.text.trim())?.toDouble()
          : double.tryParse(_value.text.trim()),
      'reward_type': _programType == 'driver_challenge' ? _challengeRewardType : _rewardType.text.trim(),
      'commission_free_trips': int.tryParse(_challengeFreeTrips.text.trim()),
      'reward_destination': _rewardDestination,
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
      'first_ride_only': _serviceMode == 'delivery' ? false : _firstRide,
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
      'commission_basis': 'company_trip',
      'company_commission_percent': double.tryParse(_leaderPercent.text.trim()),
      'benefit_months': int.tryParse(_benefitMonths.text.trim()),
      'lifetime': _lifetime,
      'period': _period,
      'exclusive': _exclusive,
      'zone_scope': _programType == 'driver_challenge' && _allChallengeZones ? 'all' : 'selected',
      'compatible_programs': _compatibleChallengeIds.toList(),
    }..removeWhere((key, value) => value == null || value == '');
    return config;
  }

  Future<void> _save([BuildContext? dialogContext]) async {
    final defaultProgramName = switch (_programType) {
      'referral' => 'Programa de referidos de conductores',
      'referral_commission' => 'Grupos MLM — comisión por referidos',
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
            (double.tryParse(_value.text.trim()) ?? 0) <= 0 ||
            (_rewardType.text == 'coupon' && _rewardDestination != 'coupon'))) {
      _showMessage('La bienvenida requiere primer viaje, pasajeros y un cupón válido.');
      return;
    }
    if (_programType == 'referral_commission' &&
        (double.tryParse(_leaderPercent.text.trim()) ?? 0) <= 0) {
      _showMessage('Indica el porcentaje de la comisión de Express.');
      return;
    }
    if (_programType == 'referral' &&
        ((double.tryParse(_referrerReward.text.trim()) ?? 0) <= 0 ||
            (double.tryParse(_referredReward.text.trim()) ?? 0) <= 0 ||
            (int.tryParse(_referralMinimumTrips.text.trim()) ?? -1) < 0)) {
      _showMessage('Completa ambas recompensas y una cantidad válida de viajes mínimos.');
      return;
    }

    setState(() => _saving = true);
    try {
      final state = _enabled && const {
        'coupon', 'activation', 'loyalty', 'driver_challenge', 'referral', 'referral_commission'
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
            ? 'Configuración MLM guardada.'
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

  void Function(VoidCallback)? _editorSetState;

  Future<void> _showEditor() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setLocal) {
        _editorSetState = setLocal;
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
                    if (_programType == 'referral')
                      _infoBox('Configura el porcentaje recurrente del líder en Grupos MLM.'),
                    if (_programType == 'activation' || _programType == 'loyalty' || _programType == 'driver_challenge')
                      _infoBox('Las recompensas se aplican al completar viajes pagados y se liquidan dentro de la app.'),
                    if (const {'coupon', 'activation', 'loyalty', 'driver_challenge'}.contains(_programType))
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_programType == 'coupon' ? 'Cupón activo' : _programType == 'driver_challenge' ? 'Reto activo' : 'Campaña activa'),
                        subtitle: const Text('Los descuentos y bonos se liquidan al completar un viaje pagado.'),
                        value: _enabled,
                        onChanged: (value) => _refreshEditor(() => _enabled = value),
                      ),
                    if (_programType == 'referral_commission') ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Programa activo'),
                        subtitle: const Text('La recompensa va a la billetera del conductor líder según las reglas del programa.'),
                        value: _enabled,
                        onChanged: (value) => _refreshEditor(() => _enabled = value),
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
      }),
    );
    _editorSetState = null;
  }

  void _refreshEditor(VoidCallback change) {
    change();
    setState(() {});
    _editorSetState?.call(() {});
  }

  String get _editorSubtitle => switch (_programType) {
        'coupon' => 'Configura el descuento, su vigencia y quién puede usarlo.',
        'activation' => 'Define el disparador y la recompensa automática.',
        'loyalty' => 'Cada N viajes pagados, el siguiente viaje del pasajero es gratis.',
        'referral' => 'Programa de referidos de conductores; la recompensa se usa dentro de la app.',
        'referral_commission' => 'El líder recibe una parte de la comisión de Express por sus referidos.',
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
            _dropdown('Tipo de descuento', _discount, const {'fixed': 'Monto fijo', 'percent': 'Porcentaje'}, (value) => _refreshEditor(() => _discount = value)),
            _textField(_discount == 'percent' ? 'Porcentaje *' : 'Monto ($_currencyLabel) *', _value, keyboard: const TextInputType.numberWithOptions(decimal: true)),
          ]),
          _twoColumns([
            _textField('Máximo de descuento ($_currencyLabel)', _maxDiscount, hint: 'Sin límite', keyboard: const TextInputType.numberWithOptions(decimal: true)),
            _segmentedField('Servicio', _serviceMode, const {'transport': 'Transporte', 'delivery': 'Delivery'}, (value) => _refreshEditor(() => _serviceMode = value)),
          ]),
          if (_serviceMode == 'transport')
            _dropdown('Tipos de servicio', _serviceType, const {'all': 'Todos los servicios', 'economy': 'Económico', 'comfort': 'Confort', 'moto': 'Moto', 'motocar': 'Motocar'}, (value) => _refreshEditor(() => _serviceType = value)),
          _textField(_serviceMode == 'delivery' ? 'Monto mínimo de pedido ($_currencyLabel)' : 'Monto mínimo de viaje ($_currencyLabel)', _minFare, hint: 'Sin mínimo', keyboard: const TextInputType.numberWithOptions(decimal: true)),
          _dropdown('Audiencia', _serviceMode == 'delivery' ? 'clients' : 'passengers',
              _serviceMode == 'delivery' ? const {'clients': 'Clientes de Delivery'} : const {'passengers': 'Pasajeros'},
              (value) => _refreshEditor(() => _audience = value)),
          _twoColumns([
            _dropdown('Audiencia objetivo', _targetAudience, const {'all': 'Todos los usuarios', 'new': 'Usuarios nuevos', 'returning': 'Usuarios frecuentes'}, (value) => _refreshEditor(() => _targetAudience = value)),
            _dropdown('Quién absorbe el descuento', _discountAbsorber, const {
              'company': 'Empresa',
              'driver': 'Conductor',
              'split': 'Distribuido (50 % empresa · 50 % conductor)',
            }, (value) => _refreshEditor(() => _discountAbsorber = value)),
          ]),
          _twoColumns([
            _textField('Usos totales máximos', _maxTotalUses, hint: 'Ilimitado', keyboard: TextInputType.number),
            _textField('Usos por usuario', _usesPerUser, hint: '1', keyboard: TextInputType.number),
          ]),
          _dateFields(),
          if (_serviceMode == 'transport')
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Solo primer viaje'),
              value: _firstRide,
              onChanged: (value) => _refreshEditor(() => _firstRide = value),
            ),
        ]);
      case 'activation':
        fields.addAll([
          _twoColumns([
            _dropdown('Tipo de disparador', _trigger, const {'first_trip': 'Primer viaje', 'paid_trips': 'Viajes pagados', 'first_delivery': 'Primer delivery'}, (value) => _refreshEditor(() => _trigger = value)),
            _textField('Valor (opcional)', _triggerValue, hint: 'Opcional', keyboard: TextInputType.number),
          ]),
          _twoColumns([
            _dropdown('Tipo de recompensa', _rewardType.text, {'fixed': 'Monto fijo ($_currencyLabel)', 'percent': 'Porcentaje', 'coupon': 'Cupón de viaje'}, (value) => _refreshEditor(() => _rewardType.text = value)),
            _textField('Valor de recompensa', _value, keyboard: const TextInputType.numberWithOptions(decimal: true)),
          ]),
          _twoColumns([
            _dropdown('Destino de recompensa', _rewardDestination, const {
              'wallet': 'Billetera',
              'coupon': 'Cupón de viaje',
            }, (value) => _refreshEditor(() => _rewardDestination = value)),
            _dropdown('Audiencia objetivo', _audience, const {'passengers': 'Pasajeros'}, (_) => _refreshEditor(() => _audience = 'passengers')),
          ]),
          _textField('Máximo de activaciones (opcional)', _maxActivations, hint: 'Sin límite', keyboard: TextInputType.number),
          _dateFields(),
        ]);
      case 'loyalty':
        fields.addAll([
          _twoColumns([
            _textField('Umbral N (viajes pagados)', _threshold, hint: '5', keyboard: TextInputType.number),
            _textField('Tope del viaje gratis ($_currencyLabel)', _maxDiscount, hint: 'Sin límite', keyboard: const TextInputType.numberWithOptions(decimal: true)),
          ]),
          _twoColumns([
            _textField('Máx. premios por cliente', _maxPerCustomer, hint: 'Sin límite', keyboard: TextInputType.number),
            _textField('Máx. premios totales', _maxTotalRewards, hint: 'Sin límite', keyboard: TextInputType.number),
          ]),
          _twoColumns([
            _textField('N.º de viajes sin comisión (conductor)', _driverNoCommission, hint: '0', keyboard: TextInputType.number),
            _textField('Máx. créditos al conductor por día', _dailyDriverCap, hint: 'Sin límite', keyboard: TextInputType.number),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Los viajes sin comisión comienzan el mismo día'),
            subtitle: const Text('Apagado: comienzan al día siguiente del viaje premiado.'),
            value: _sameDayCredits,
            onChanged: (value) => _refreshEditor(() => _sameDayCredits = value),
          ),
          _infoBox('Cada N viajes pagados, el pasajero recibe un cupón para su siguiente viaje. El conductor puede recibir viajes sin comisión según esta configuración.'),
          _dateFields(),
        ]);
      case 'referral':
        fields.addAll([
          const Text('Recompensa para quien refiere', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _twoColumns([
            _dropdown('Tipo de recompensa', _referrerType, const {'fixed': 'Monto fijo'}, (value) => _refreshEditor(() => _referrerType = value)),
            _textField('Valor ($_currencyLabel)', _referrerReward, keyboard: const TextInputType.numberWithOptions(decimal: true)),
          ]),
          _dropdown('Destino', _referrerDestination, const {'wallet': 'Monedero'}, (value) => _refreshEditor(() => _referrerDestination = value)),
          const SizedBox(height: 14),
          const Text('Recompensa para el conductor referido', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _twoColumns([
            _dropdown('Tipo de recompensa', _referredType, const {'fixed': 'Monto fijo'}, (value) => _refreshEditor(() => _referredType = value)),
            _textField('Valor ($_currencyLabel)', _referredReward, keyboard: const TextInputType.numberWithOptions(decimal: true)),
          ]),
          _dropdown('Destino', _referredDestination, const {'wallet': 'Monedero'}, (value) => _refreshEditor(() => _referredDestination = value)),
          _twoColumns([
            _textField('Viajes mínimos para activar', _referralMinimumTrips, keyboard: TextInputType.number),
            _textField('Máximo de referidos por usuario', _maxReferrals, hint: 'Sin límite', keyboard: TextInputType.number),
          ]),
          _infoBox('Este programa es para conductores. A los pasajeros se les asignan cupones, no saldo retirable.'),
        ]);
      case 'referral_commission':
        fields.addAll([
          _textField('Porcentaje de la comisión de Express por viaje', _leaderPercent, hint: 'Ej.: 1', keyboard: const TextInputType.numberWithOptions(decimal: true)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Beneficio de por vida'),
            value: _lifetime,
            onChanged: (value) => _refreshEditor(() => _lifetime = value),
          ),
          if (!_lifetime) _textField('Vigencia del beneficio (meses)', _benefitMonths, keyboard: TextInputType.number),
          _infoBox('El líder recibe el porcentaje configurado de la comisión de Express por cada viaje completado y pagado de sus conductores referidos.'),
        ]);
      case 'driver_challenge':
        fields.addAll([
          _twoColumns([
            _textField('Meta (número de viajes) *', _threshold, hint: '10', keyboard: TextInputType.number),
            _dropdown('Periodo', _period, const {'daily': 'Diario', 'weekly': 'Semanal', 'monthly': 'Mensual', 'custom': 'Personalizado'}, (value) => _refreshEditor(() => _period = value)),
          ]),
          _dateFields(),
          _twoColumns([
            _dropdown('Tipo de recompensa', _challengeRewardType, const {
              'commission_free': 'Viajes sin comisión',
              'wallet': 'Bono en billetera interna',
            }, (value) => _refreshEditor(() => _challengeRewardType = value)),
            _challengeRewardType == 'commission_free'
                ? _textField('Número de viajes sin comisión', _challengeFreeTrips, hint: 'Ej.: 100', keyboard: TextInputType.number)
                : _textField('Monto del bono ($_currencyLabel)', _value, keyboard: const TextInputType.numberWithOptions(decimal: true)),
          ]),
          _dropdown('Dirigido a', _audience, const {'drivers': 'Conductores', 'all': 'Todos los usuarios'}, (value) => _refreshEditor(() => _audience = value)),
          _dropdown('Zona', _allChallengeZones ? 'all' : 'selected', const {
            'all': 'Toda la app (todas las zonas)',
            'selected': 'Solo esta zona',
          }, (value) => _refreshEditor(() => _allChallengeZones = value == 'all')),
          if (!_allChallengeZones)
            _infoBox('Zona seleccionada: ${_zoneLabel ?? 'zona actual'}'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reto exclusivo (el conductor no puede inscribirse a otros retos)'),
            value: _exclusive,
            onChanged: (value) => _refreshEditor(() => _exclusive = value),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('Compatible con (opcional)', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (_challengeRows.isEmpty)
            _infoBox('No hay otros retos disponibles para combinar en esta zona y entorno.')
          else
            ..._challengeRows.where((challenge) => challenge['id']?.toString() != _editingId).map((challenge) {
              final id = challenge['id']?.toString() ?? '';
              final name = challenge['name']?.toString() ?? 'Reto';
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _compatibleChallengeIds.contains(id),
                title: Text(name),
                onChanged: (selected) => _refreshEditor(() {
                  if (selected == true) {
                    _compatibleChallengeIds.add(id);
                  } else {
                    _compatibleChallengeIds.remove(id);
                  }
                }),
              );
            }),
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
            _refreshEditor(() {
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
        if (_programType == 'driver_challenge') {
          _challengeRows = rows;
        }
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
              setState(() {
                _couponTab = value;
                _clear();
                _rewardDestination = value == 'rules' ? 'wallet' : 'coupon';
                _filter = 'all';
                _reload();
              });
              }),
            ],
            if (_category == 'referral') ...[
              const SizedBox(height: 10),
              _subTabs({'program': 'Programa', 'referrals': 'Referidos', 'mlm': 'Grupos MLM'}, _referralTab, (value) {
                setState(() { _referralTab = value; _clear(); _filter = 'all'; _reload(); });
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
                _category = item.$1;
                _clear();
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
    final uses = _sumConfig(rows, 'uses');
    final discountTotal = _sumConfigAmount(rows, 'discount_total');
    final activations = _sumConfig(rows, 'activations');
    final participants = _sumConfig(rows, 'participants');
    final awards = _sumConfig(rows, 'awards');
    final redeemed = _sumConfig(rows, 'redeemed');
    final driverCredits = _sumConfigAmount(rows, 'driver_credits');
    final challengeParticipants = _sumConfig(rows, 'challenge_participants');
    final challengeAwards = _sumConfig(rows, 'challenge_awards');
    final challengeSuccess = challengeParticipants == 0
        ? 0
        : (challengeAwards * 100 / challengeParticipants).clamp(0, 100);
    final items = switch (_programType) {
      'coupon' => <(String, String, IconData)>[
          ('Total Cupones', '${rows.length}', Icons.local_offer_outlined),
          ('Activos', '$active', Icons.confirmation_num_outlined),
          ('Canjes Totales', '$uses', Icons.people_outline),
          ('Descuento Total', _metricNumber(discountTotal), Icons.payments_outlined),
        ],
      'activation' => <(String, String, IconData)>[
          ('Total Reglas', '${rows.length}', Icons.bolt_outlined),
          ('Reglas Activas', '$active', Icons.track_changes_outlined),
          ('Total Activaciones', '$activations', Icons.trending_up_rounded),
        ],
      'loyalty' => <(String, String, IconData)>[
          ('Total Campañas', '${rows.length}', Icons.card_giftcard_outlined),
          ('Clientes Participando', '$participants', Icons.people_outline),
          ('Premios Otorgados', '$awards', Icons.emoji_events_outlined),
          ('Créditos a Conductores', _metricNumber(driverCredits), Icons.directions_car_outlined),
        ],
      'referral' || 'referral_commission' => <(String, String, IconData)>[
          ('Total Referidos', '${_sumConfig(rows, 'referrals')}', Icons.people_alt_outlined),
          ('Pendientes', '${_sumConfig(rows, 'pending_referrals')}', Icons.schedule_outlined),
          ('Activados', '${_sumConfig(rows, 'activated_referrals')}', Icons.check_circle_outline),
          ('Tasa Conversión', '${_sumConfig(rows, 'referral_conversion').toStringAsFixed(0)}%', Icons.trending_up_rounded),
        ],
      'driver_challenge' => <(String, String, IconData)>[
          ('Total Retos', '${rows.length}', Icons.flag_outlined),
          ('Inscripciones del período', '$challengeParticipants', Icons.people_outline),
          ('Retos completados', '$challengeAwards', Icons.emoji_events_outlined),
          ('Tasa de éxito', '${challengeSuccess.toStringAsFixed(0)}%', Icons.trending_up_rounded),
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

  int _sumConfig(List<Map<String, dynamic>> rows, String key) {
    return rows.fold<int>(0, (total, row) {
      final config = row['config'];
      final value = config is Map ? config[key] : null;
      return total + (value is num ? value.toInt() : int.tryParse('$value') ?? 0);
    });
  }

  double _sumConfigAmount(List<Map<String, dynamic>> rows, String key) {
    return rows.fold<double>(0, (total, row) {
      final config = row['config'];
      final value = config is Map ? config[key] : null;
      return total + (value is num ? value.toDouble() : double.tryParse('$value') ?? 0);
    });
  }

  String _metricNumber(double value) => value.toStringAsFixed(value % 1 == 0 ? 0 : 2);

  List<String> get _tableHeaders => switch (_programType) {
        'coupon' => const ['Código', 'Módulo', 'Tipo', 'Valor', 'Usos', 'Vigencia', 'Audiencia', 'Estado', 'Acciones'],
        'activation' => const ['Nombre', 'Disparador', 'Recompensa', 'Audiencia', 'Activaciones', 'Estado', 'Acciones'],
        'loyalty' => const ['Nombre', 'Umbral', 'Premio conductor', 'Participando', 'Otorgados', 'Cobrados', 'Créditos', 'Estado', 'Acciones'],
        'referral' => const ['Programa', 'Premio quien refiere', 'Premio referido', 'Condición', 'Estado', 'Acciones'],
        'referral_commission' => const ['Programa MLM', '% comisión Express', 'Vigencia', 'Estado', 'Acciones'],
        'driver_challenge' => const ['Nombre', 'Meta', 'Período', 'Recompensa', 'Inscritos (período)', 'Completados', 'Estado', 'Acciones'],
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
          _audienceLabel(config['audience'], 'Pasajeros'), state, actions,
        ],
      'activation' => [
          row['name']?.toString() ?? '—', config['trigger_type']?.toString() ?? 'Primer viaje',
          '${config['reward_type'] ?? 'Monto fijo'} ${config['value'] ?? '—'}',
          _audienceLabel(config['audience'], 'Clientes'), '${config['activations'] ?? 0}', state, actions,
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
          row['name']?.toString() ?? 'Grupos MLM',
          '${config['company_commission_percent'] ?? config['plan_payment_percent'] ?? '—'}%',
          config['lifetime'] == true ? 'De por vida' : '${config['benefit_months'] ?? '—'} meses', state, actions,
        ],
      'driver_challenge' => [
          row['name']?.toString() ?? '—', '${config['trip_goal'] ?? '—'} viajes',
          config['period']?.toString() ?? '—',
          config['reward_type'] == 'commission_free'
              ? '${config['commission_free_trips'] ?? config['value'] ?? 0} viajes sin comisión'
              : 'Billetera ${config['value'] ?? '—'}',
          '${config['challenge_participants'] ?? 0}', '${config['challenge_awards'] ?? 0}', state, actions,
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
            const Text('Configuración del Programa', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const Text('Define las recompensas y condiciones para quien invita y para el referido.', style: TextStyle(color: _muted)),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Programa activo'),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            const Text('Recompensa para quien refiere', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _twoColumns([
              _dropdown('Tipo de recompensa', _referrerType, const {'fixed': 'Monto fijo'}, (value) => setState(() => _referrerType = value)),
              _textField('Valor', _referrerReward, keyboard: const TextInputType.numberWithOptions(decimal: true)),
            ]),
            _dropdown('Destino', _referrerDestination, const {'wallet': 'Monedero'}, (value) => setState(() => _referrerDestination = value)),
            const Text('Recompensa para el referido', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _twoColumns([
              _dropdown('Tipo de recompensa', _referredType, const {'fixed': 'Monto fijo'}, (value) => setState(() => _referredType = value)),
              _textField('Valor', _referredReward, keyboard: const TextInputType.numberWithOptions(decimal: true)),
            ]),
            _dropdown('Destino', _referredDestination, const {'wallet': 'Monedero'}, (value) => setState(() => _referredDestination = value)),
            _twoColumns([
              _textField('Viajes pagados mínimos para activar', _referralMinimumTrips, hint: '0', keyboard: TextInputType.number),
              _textField('Máximo de referidos por usuario', _maxReferrals, hint: 'Sin límite', keyboard: TextInputType.number),
            ]),
            _infoBox('La moneda y la zona se determinan por la zona seleccionada arriba. No cambia el entorno de datos de la cuenta.'),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: const Text('Guardar configuración')),
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
            const Text('Grupos MLM — Comisión recurrente por referidos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const Text('El líder recibe el porcentaje configurado de la comisión de Express por cada viaje completado de sus conductores referidos. La comisión sale del corte de la empresa, no del conductor referido.', style: TextStyle(color: _muted)),
            const SizedBox(height: 20),
            _twoColumns([
              _textField('Porcentaje de la comisión de la empresa', _leaderPercent, hint: 'Ej.: 1', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              if (!_lifetime) _textField('Vigencia del beneficio (meses)', _benefitMonths, keyboard: TextInputType.number),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Beneficio de por vida'),
              subtitle: const Text('Si está activo, el beneficio no vence mientras el conductor referido complete viajes.'),
              value: _lifetime,
              onChanged: (value) => setState(() => _lifetime = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Programa activo'),
              subtitle: const Text('Acredita la recompensa al líder en la billetera interna cuando se paga un viaje elegible.'),
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
          final currency = dashboard['currency']?.toString() ?? 'BOB';
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
            _referralHistory(referrals, currency),
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

  Widget _referralHistory(List<Map<String, dynamic>> referrals, String currency) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(side: const BorderSide(color: _line), borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Lista de Referidos', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _ink)),
            const Text('Historial de conductores, viajes y recompensas acreditadas.', style: TextStyle(color: _muted, fontSize: 12)),
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
                    DataColumn(label: Text('Movimientos')),
                    DataColumn(label: Text('Recompensa acreditada')),
                    DataColumn(label: Text('Última actividad')),
                  ],
                  rows: referrals.where((row) => _referralTypeFilter == 'all' || _referralTypeFilter == 'driver').map((row) {
                    final state = row['state']?.toString() ?? 'pending';
                    final status = switch (state) {
                      'qualified' => 'Activado',
                      'reward_review' => 'En revisión',
                      'closed' => 'Cerrado',
                      _ => 'Pendiente',
                    };
                    final lastPayment = DateTime.tryParse(row['last_activity_at']?.toString() ?? '');
                    return DataRow(cells: [
                      DataCell(Text(row['referrer_name']?.toString() ?? '—')),
                      DataCell(Text(row['referral_code']?.toString() ?? '—')),
                      DataCell(Text(row['referred_name']?.toString() ?? '—')),
                      DataCell(Text(status)),
                      DataCell(Text('${_intValue(row['activity_count'])}')),
                      DataCell(Text('$currency ${_numberValue(row['commission_total']).toStringAsFixed(2)}')),
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
        'referral_commission' => 'Porcentaje de la comisión de Express por los viajes de los conductores referidos.',
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

/// Texto legible de la audiencia de un beneficio, en lugar del valor técnico.
String _audienceLabel(Object? audience, String fallback) {
  return switch (audience?.toString() ?? '') {
    'drivers' => 'Conductores',
    'passengers' => 'Pasajeros',
    'clients' => 'Clientes de Delivery',
    'all' => 'Todos los usuarios',
    _ => fallback,
  };
}
