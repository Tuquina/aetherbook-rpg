import 'package:flutter/material.dart';

import 'design/tokens.dart';
import 'design/typography.dart';
import 'widgets/atmosphere.dart';
import 'world_select_screen.dart'
    show StoryModule, StoryModuleInfo, storyModuleStyle;

/// The Codex — how the game works (GDD §9: rules always within reach). Split
/// into two tabs (V2 design prototype §3b/3c/3d, "particionado por modo"):
/// "Formas de jugar" leads into a rich per-module explainer
/// ([_ModeDetailScreen]) instead of the flat one-line-per-module list this
/// screen used to show inline; "Reglas" keeps the general mechanics
/// explainers (Fate Rolls, progression, resources, etc.) that apply
/// regardless of which module a story belongs to.
class CodexScreen extends StatelessWidget {
  const CodexScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const CodexScreen());

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: AetherBackground(
          particles: false,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    _header(context),
                    const TabBar(
                      labelColor: AetherColors.goldBright,
                      unselectedLabelColor: AetherColors.parchmentDim,
                      indicatorColor: AetherColors.gold,
                      labelStyle: AetherType.label,
                      tabs: [
                        Tab(text: 'Formas de jugar'),
                        Tab(text: 'Reglas'),
                      ],
                    ),
                    const Expanded(
                      child: TabBarView(
                        children: [_ModesTab(), _RulesTab()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AetherSpace.sm, AetherSpace.sm, AetherSpace.lg, AetherSpace.sm),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AetherColors.goldSoft),
            ),
            const SizedBox(width: AetherSpace.xs),
            Text('El Códice', style: AetherType.display.copyWith(fontSize: 22)),
          ],
        ),
      );
}

class _ModesTab extends StatelessWidget {
  const _ModesTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AetherSpace.lg, AetherSpace.sm, AetherSpace.lg, AetherSpace.huge),
      children: [
        const _Section(
          icon: Icons.auto_stories_rounded,
          title: 'Un mundo que te escucha',
          body:
              'Aetherbook es un RPG narrativo: la historia se escribe en tiempo '
              'real según tus decisiones. Un narrador de IA le da voz al mundo, '
              'pero no manda sobre él. Tus atributos, recursos, inventario y las '
              'huellas de tus decisiones los controla el motor, de forma justa y '
              'determinista. La IA nunca inventa un resultado: solo narra, con '
              'estilo, lo que el motor ya resolvió.',
        ),
        Container(
          margin: const EdgeInsets.only(bottom: AetherSpace.md),
          decoration: BoxDecoration(
            color: AetherColors.surface,
            borderRadius: AetherRadius.allLg,
            border: Border.all(color: AetherColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AetherSpace.lg, AetherSpace.lg, AetherSpace.lg, AetherSpace.sm),
                child: Row(
                  children: [
                    const Icon(Icons.route_rounded, color: AetherColors.gold, size: 20),
                    const SizedBox(width: AetherSpace.md),
                    Expanded(
                        child: Text('Tres formas de jugar', style: AetherType.title)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AetherSpace.lg),
                child: Text(
                  'No todas las historias se cuentan igual. Toca una para ver '
                  'qué controlas vos y qué ya viene decidido.',
                  style: AetherType.body,
                ),
              ),
              const SizedBox(height: AetherSpace.md),
              for (final module in StoryModule.values)
                _ModeRow(module: module, onTap: () => _openMode(context, module)),
              const SizedBox(height: AetherSpace.sm),
            ],
          ),
        ),
      ],
    );
  }

  void _openMode(BuildContext context, StoryModule module) {
    Navigator.of(context).push(_ModeDetailScreen.route(module));
  }
}

/// One tappable row per [StoryModule] — same copy/icon/accent as
/// `WorldSelectScreen`'s picker cards (via `storyModuleStyle`), now leading
/// into [_ModeDetailScreen] instead of just restating the one-line
/// description inline.
class _ModeRow extends StatelessWidget {
  const _ModeRow({required this.module, required this.onTap});

  final StoryModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = storyModuleStyle(module);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AetherSpace.lg, vertical: AetherSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: style.accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(color: style.accent.withValues(alpha: 0.5)),
              ),
              child: Icon(style.icon, color: style.bright, size: 16),
            ),
            const SizedBox(width: AetherSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(module.title,
                      style: AetherType.label.copyWith(color: style.bright)),
                  const SizedBox(height: 2),
                  Text(module.teaser,
                      style: AetherType.body.copyWith(fontSize: 14.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: style.accent.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}

class _RulesTab extends StatelessWidget {
  const _RulesTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AetherSpace.lg, AetherSpace.sm, AetherSpace.lg, AetherSpace.huge),
      children: [
        const _Section(
          icon: Icons.casino_rounded,
          title: 'Las Tiradas del Destino',
          body:
              'Cuando intentas algo de resultado incierto —ya sea escribiendo tu '
              'propia acción o eligiendo una opción marcada con una tirada—, el '
              'motor lo resuelve así:',
          child: _FateExplainer(),
        ),
        const _Section(
          icon: Icons.hub_rounded,
          title: 'Todo deja huella',
          body:
              'El resultado de cada tirada cambia el estado del mundo: ganas '
              'experiencia, tus recursos suben o bajan, se encienden marcas de '
              'trama (secretos revelados, vínculos, decisiones). Ese estado '
              'moldea lo que viene: lo que haces hoy abre o cierra caminos '
              'mañana, y puede cambiar quién sobrevive o cómo termina la '
              'historia. Cuando una decisión no tiene vuelta atrás, el juego te '
              'lo advierte y te pide confirmar antes de resolverla — el mundo '
              'recuerda, así que elegir importa.',
        ),
        const _Section(
          icon: Icons.trending_up_rounded,
          title: 'Progresión',
          body:
              'Tus acciones te dan experiencia y, al acumularla, asciendes de '
              'reino. Cada reino no es solo un número más alto: desbloquea '
              'opciones, técnicas y caminos que antes te estaban vedados.',
        ),
        const _Section(
          icon: Icons.local_fire_department_rounded,
          title: 'Recursos',
          body:
              'El qi, la salud y demás recursos son finitos. Gastarlos tiene '
              'consecuencias, y quedarte sin ellos también. Administrarlos es '
              'parte de sobrevivir y de decidir cuándo arriesgar. Los ves '
              'siempre a mano, arriba de la pantalla de juego.',
        ),
        const _Section(
          icon: Icons.inventory_2_rounded,
          title: 'Tu inventario',
          body:
              'Lo que encuentras, te dan o consigues durante la partida queda '
              'registrado con nombre y descripción propios — no son solo '
              'objetos sueltos. Se accede desde el ícono de mochila en la '
              'barra de estado, arriba de la pantalla de juego.',
        ),
        const _Section(
          icon: Icons.balance_rounded,
          title: 'La economía de decisiones',
          body:
              'Ninguna elección es gratis. Cada acción define quién eres: honrar '
              'o traicionar, atesorar tu humanidad o perseguir el poder. El '
              'mundo responde a esa moneda invisible, y la historia se ramifica '
              'según en qué gastas.',
        ),
      ],
    );
  }
}

/// One feature bullet inside [_ModeDetailScreen]: icon + short title + a
/// line of body copy, mirroring V2 §3b/3c/3d's three-feature-row pattern.
class _ModeFeature {
  const _ModeFeature({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}

/// What the player controls vs. what's already decided for them, shown as a
/// two-column check/block grid (V2 §3b/3c/3d's "Qué controlas").
class _ModeControlSplit {
  const _ModeControlSplit({required this.controls, required this.fixed});

  final String controls;
  final String fixed;
}

/// Per-module deep-dive content. Adapted from the design prototype's
/// structure (intro, 3 feature rows, "qué controlas" grid, CTA) — but the
/// wording itself is written against how each module actually behaves in
/// *this* app, not translated verbatim from the mockup: the mockup's own
/// "Historias pre-armadas" copy (fixed origins, no chargen) actually
/// describes what this app calls "Crea tu propia historia" (5 freeform
/// genres with real chargen), and its "Crea tu propia" copy describes a
/// freeform seed-prompt mode this app doesn't have. Reusing that text
/// as-is would describe modules that don't match what a player actually
/// picks from `WorldSelectScreen`.
const Map<StoryModule, List<_ModeFeature>> _modeFeatures = {
  StoryModule.complete: [
    _ModeFeature(
      icon: Icons.person_rounded,
      title: 'Un protagonista con nombre propio',
      body: 'Elegís entre un puñado de perfiles ya escritos, cada uno con su '
          'propio pasado y objeto personal — no armás atributos desde cero.',
    ),
    _ModeFeature(
      icon: Icons.menu_book_rounded,
      title: 'Capítulos con destino fijo',
      body: 'Cada capítulo cierra donde el autor decidió que cerrara. Vos '
          'elegís cómo llegar, no adónde.',
    ),
    _ModeFeature(
      icon: Icons.flag_rounded,
      title: 'Varios finales, todos escritos a mano',
      body: 'Tus decisiones eligen cuál final te toca, entre varios ya '
          'redactados — nunca improvisados.',
    ),
  ],
  StoryModule.preArmada: [
    _ModeFeature(
      icon: Icons.public_rounded,
      title: 'El mundo y el conflicto ya existen',
      body: 'La ambientación, los personajes y el problema central están '
          'escritos; vos aportás quién sos dentro de eso.',
    ),
    _ModeFeature(
      icon: Icons.route_rounded,
      title: 'Un armazón de hitos, prosa en vivo',
      body: 'La estructura general — capítulos, encrucijadas, el clímax — '
          'está fija; cómo se narra cada turno lo decide la IA según lo que '
          'hacés.',
    ),
    _ModeFeature(
      icon: Icons.history_edu_rounded,
      title: 'Un juramento que se pone a prueba',
      body: 'Elegís una promesa al crear tu personaje. El narrador la va a '
          'desafiar — cumplirla o romperla cambia tu final.',
    ),
  ],
  StoryModule.aiNarrator: [
    _ModeFeature(
      icon: Icons.category_rounded,
      title: 'Elegís género, no guion',
      body: 'Isekai, Xianxia, Superhéroes, Cyberpunk o Post-apocalíptico: el '
          'género pone el tono y el vocabulario de tu personaje; la trama la '
          'escribe la IA con vos, turno a turno.',
    ),
    _ModeFeature(
      icon: Icons.menu_book_rounded,
      title: 'El Códice se llena solo',
      body: 'Cada nombre que aparece en tu historia queda registrado acá, en '
          'Lugares y Personas, a medida que lo descubrís.',
    ),
    _ModeFeature(
      icon: Icons.all_inclusive_rounded,
      title: 'No termina',
      body: 'Seguís mientras quieras. Podés tener varias historias del mismo '
          'género a la vez, cada una por su cuenta.',
    ),
  ],
};

const Map<StoryModule, _ModeControlSplit> _modeControlSplits = {
  StoryModule.complete: _ModeControlSplit(
    controls: 'Qué hacés, con quién te alías, qué llegás a descubrir',
    fixed: 'Quién sos, el mundo, el conflicto central, el final disponible',
  ),
  StoryModule.preArmada: _ModeControlSplit(
    controls: 'Tu personaje, tus decisiones turno a turno, si tu juramento '
        'se sostiene',
    fixed: 'El armazón de la campaña, sus hitos y su clímax',
  ),
  StoryModule.aiNarrator: _ModeControlSplit(
    controls: 'Tu personaje, el género, cada decisión, cuándo parar',
    fixed: 'Nada — no hay un final fijo esperándote',
  ),
};

const Map<StoryModule, String> _modeCtaLabels = {
  StoryModule.complete: 'Volver a las formas de jugar',
  StoryModule.preArmada: 'Volver a las formas de jugar',
  StoryModule.aiNarrator: 'Volver a las formas de jugar',
};

/// The per-module deep dive (V2 §3b/3c/3d): intro, 3 feature rows, a
/// "qué controlas" check/block grid, and a CTA that returns to the Codex —
/// this screen is purely informational, reachable from any of `CodexScreen`'s
/// callers (some of which don't carry a `GameController` at all), so it
/// doesn't try to launch chargen/story-selection itself.
class _ModeDetailScreen extends StatelessWidget {
  const _ModeDetailScreen({required this.module});

  final StoryModule module;

  static Route<void> route(StoryModule module) => MaterialPageRoute(
        builder: (_) => _ModeDetailScreen(module: module),
      );

  @override
  Widget build(BuildContext context) {
    final style = storyModuleStyle(module);
    final features = _modeFeatures[module]!;
    final split = _modeControlSplits[module]!;
    return Scaffold(
      body: AetherBackground(
        particles: false,
        accent: style.accent,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AetherSpace.sm, AetherSpace.sm,
                        AetherSpace.lg, AetherSpace.sm),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: AetherColors.goldSoft),
                        ),
                        const SizedBox(width: AetherSpace.xs),
                        Expanded(
                          child: Text(module.title,
                              style: AetherType.display.copyWith(fontSize: 20)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(AetherSpace.lg, 0,
                          AetherSpace.lg, AetherSpace.huge),
                      children: [
                        Text(module.description, style: AetherType.body),
                        const SizedBox(height: AetherSpace.xl),
                        for (final feature in features)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AetherSpace.md),
                            child: _FeatureRow(feature: feature, accent: style.bright),
                          ),
                        const SizedBox(height: AetherSpace.sm),
                        Text('QUÉ CONTROLAS',
                            style: AetherType.overline
                                .copyWith(color: AetherColors.parchmentFaint)),
                        const SizedBox(height: AetherSpace.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _ControlCard(
                                icon: Icons.check_rounded,
                                color: AetherColors.success,
                                text: split.controls,
                              ),
                            ),
                            const SizedBox(width: AetherSpace.sm),
                            Expanded(
                              child: _ControlCard(
                                icon: Icons.block_rounded,
                                color: AetherColors.failure,
                                text: split.fixed,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AetherSpace.xl),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: style.accent.withValues(alpha: 0.55)),
                              foregroundColor: style.bright,
                              padding: const EdgeInsets.symmetric(vertical: AetherSpace.md),
                              shape: RoundedRectangleBorder(borderRadius: AetherRadius.allMd),
                            ),
                            child: Text(_modeCtaLabels[module]!, style: AetherType.label),
                          ),
                        ),
                      ],
                    ),
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

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature, required this.accent});

  final _ModeFeature feature;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(feature.icon, color: accent, size: 20),
        const SizedBox(width: AetherSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(feature.title, style: AetherType.title.copyWith(fontSize: 15.5)),
              const SizedBox(height: 3),
              Text(feature.body, style: AetherType.body.copyWith(fontSize: 14.5)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AetherSpace.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: AetherRadius.allMd,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(height: AetherSpace.sm),
          Text(text, style: AetherType.body.copyWith(fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.body,
    this.child,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AetherSpace.md),
      padding: const EdgeInsets.all(AetherSpace.lg),
      decoration: BoxDecoration(
        color: AetherColors.surface,
        borderRadius: AetherRadius.allLg,
        border: Border.all(color: AetherColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AetherColors.gold, size: 20),
              const SizedBox(width: AetherSpace.md),
              Expanded(child: Text(title, style: AetherType.title)),
            ],
          ),
          const SizedBox(height: AetherSpace.md),
          Text(body, style: AetherType.body),
          if (child != null) ...[
            const SizedBox(height: AetherSpace.lg),
            child!,
          ],
        ],
      ),
    );
  }
}

/// The visual key for how a roll is built and banded.
class _FateExplainer extends StatelessWidget {
  const _FateExplainer();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The formula.
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AetherSpace.md, vertical: AetherSpace.md),
          decoration: BoxDecoration(
            color: AetherColors.void_,
            borderRadius: AetherRadius.allMd,
            border: Border.all(color: AetherColors.hairline),
          ),
          child: Wrap(
            spacing: AetherSpace.sm,
            runSpacing: AetherSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _chip('atributo', AetherColors.goldSoft),
              const Text('+', style: TextStyle(color: AetherColors.parchmentFaint)),
              _chip('d20', AetherColors.goldSoft),
              const Text('vs', style: TextStyle(color: AetherColors.parchmentFaint)),
              _chip('dificultad', AetherColors.parchmentDim),
            ],
          ),
        ),
        const SizedBox(height: AetherSpace.md),
        Text(
          'El atributo que se usa depende de tu acción: forzar una puerta pone a '
          'prueba tu Cuerpo; descifrar un manuscrito, tu Mente; sentir el flujo '
          'del qi, tu Espíritu. El d20 es el azar; la dificultad, lo que se te '
          'opone.',
          style: AetherType.body.copyWith(fontSize: 15),
        ),
        const SizedBox(height: AetherSpace.lg),
        // The three bands.
        _band(AetherColors.failure, 'Falla',
            'El total no alcanza la dificultad. El intento se te escapa.'),
        _band(AetherColors.success, 'Éxito',
            'Alcanzas o superas la dificultad. El mundo cede a tu voluntad.'),
        _band(AetherColors.critical, 'Éxito crítico',
            'La superas por un amplio margen: algo memorable ocurre.'),
        const SizedBox(height: AetherSpace.md),
        Row(
          children: [
            const Icon(Icons.stars_rounded,
                size: 15, color: AetherColors.goldBright),
            const SizedBox(width: AetherSpace.sm),
            Expanded(
              child: Text(
                'Un 20 natural en el dado siempre es crítico; un 1 natural, '
                'siempre falla — pase lo que pase.',
                style: AetherType.caption.copyWith(fontSize: 12.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AetherColors.surfaceRaised,
          borderRadius: AetherRadius.allSm,
          border: Border.all(color: AetherColors.hairline),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      );

  Widget _band(Color color, String name, String meaning) => Padding(
        padding: const EdgeInsets.only(bottom: AetherSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 3),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: AetherShadow.glow(color, strength: 0.5),
              ),
            ),
            const SizedBox(width: AetherSpace.md),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: AetherType.body.copyWith(fontSize: 14.5),
                  children: [
                    TextSpan(
                        text: '$name. ',
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w700)),
                    TextSpan(text: meaning),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
