import 'package:flutter/material.dart';

import 'design/tokens.dart';
import 'design/typography.dart';
import 'widgets/atmosphere.dart';

/// The Codex — how the game works (GDD §9: rules always within reach). Explains
/// that the story is alive but the state is authoritative, what the Fate Rolls
/// mean, and — crucially — how rolls, progression, resources and the economy of
/// decisions all feed back into the story.
class CodexScreen extends StatelessWidget {
  const CodexScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const CodexScreen());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AetherBackground(
        child: SafeArea(
          child: Column(
            children: [
              _header(context),
              const Expanded(child: _CodexBody()),
            ],
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

class _CodexBody extends StatelessWidget {
  const _CodexBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AetherSpace.lg, AetherSpace.sm, AetherSpace.lg, AetherSpace.huge),
      children: const [
        _Section(
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
        _Section(
          icon: Icons.casino_rounded,
          title: 'Las Tiradas del Destino',
          body:
              'Cuando intentás algo de resultado incierto, el motor lo resuelve '
              'con una tirada:',
          child: _FateExplainer(),
        ),
        _Section(
          icon: Icons.hub_rounded,
          title: 'Todo deja huella',
          body:
              'El resultado de cada tirada cambia el estado del mundo: ganás '
              'experiencia, tus recursos suben o bajan, se encienden marcas de '
              'trama (secretos revelados, vínculos, decisiones). Y ese estado '
              'moldea lo que viene: lo que hacés hoy abre o cierra caminos '
              'mañana. El mundo recuerda.',
        ),
        _Section(
          icon: Icons.trending_up_rounded,
          title: 'Progresión',
          body:
              'Tus acciones te dan experiencia y, al acumularla, ascendés de '
              'reino. Cada reino no es solo un número más alto: desbloquea '
              'opciones, técnicas y caminos que antes te estaban vedados.',
        ),
        _Section(
          icon: Icons.local_fire_department_rounded,
          title: 'Recursos',
          body:
              'El qi, la salud y demás recursos son finitos. Gastarlos tiene '
              'consecuencias, y quedarte sin ellos también. Administrarlos es '
              'parte de sobrevivir y de decidir cuándo arriesgar.',
        ),
        _Section(
          icon: Icons.balance_rounded,
          title: 'La economía de decisiones',
          body:
              'Ninguna elección es gratis. Cada acción define quién sos: honrar '
              'o traicionar, atesorar tu humanidad o perseguir el poder. El '
              'mundo responde a esa moneda invisible, y la historia se ramifica '
              'según en qué gastás.',
        ),
      ],
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
            'Alcanzás o superás la dificultad. El mundo cede a tu voluntad.'),
        _band(AetherColors.critical, 'Éxito crítico',
            'La superás por un amplio margen: algo memorable ocurre.'),
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
