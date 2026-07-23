import 'dart:convert';

import '../../core/engine/action_resolution.dart';
import '../../ports/narrator_port.dart';
import 'narrator_json_parser.dart';

/// A narrator that returns fixed, valid JSON — no network, no quota. It lets
/// the whole loop be played and tested offline (CLAUDE.md §9). The canned
/// payload is deliberately wrapped in a ```json fence so the tolerant parser
/// (and the future Gemini adapter's parse path) is exercised on every turn.
///
/// It is NOT an AI: the prose is canned per outcome band. Its purpose is to
/// prove the contract and the loop, not to write good stories.
class FakeNarratorAdapter implements NarratorPort {
  const FakeNarratorAdapter({
    this.latency = const Duration(milliseconds: 450),
  });

  /// Simulated "thinking" time, so the UI's loading state is visible.
  final Duration latency;

  @override
  Future<NarratorResponse> narrate(NarratorRequest request) async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
    return parseNarratorJson(_fenced(_payloadFor(request)));
  }

  String _payloadFor(NarratorRequest request) {
    final resolution = request.resolution;
    if (resolution == null) {
      return _json(
        narration: request.world.seedNarration.isNotEmpty
            ? request.world.seedNarration
            : 'El sendero se abre ante vos.',
        choices: _choicesFrom(request.world.seedChoices),
        deltas: const [],
        imagePrompt: 'Un discípulo ante un sendero de montaña',
        tone: request.world.tone,
        world: request,
      );
    }

    switch (resolution.outcome) {
      case ActionOutcome.criticalSuccess:
        return _json(
          narration:
              'Con maestría inesperada, "${request.playerAction}" sale mejor '
              'de lo que imaginabas. El qi fluye limpio a través de tus '
              'meridianos y algo dentro de vos se afianza.',
          choices: _choicesFrom(const [
            'Consolidar el avance en meditación',
            'Aprovechar el impulso y adentrarte más',
            'Buscar a alguien que atestigüe tu progreso',
          ]),
          deltas: const [
            {
              'type': 'exp',
              'key': 'exp',
              'value': 300,
              'operation': 'increment',
              'reason': 'Éxito crítico en la acción intentada.',
            },
            {
              'type': 'resource',
              'key': 'qi',
              'value': 3,
              'operation': 'increment',
              'reason': 'El qi fluyó limpio durante el avance.',
            },
            {
              'type': 'flag',
              'key': 'tuvo_un_avance',
              'value': true,
              'operation': 'increment',
              'reason': 'Marca el primer avance de cultivo del personaje.',
            },
          ],
          imagePrompt: 'Aura dorada de qi rodeando a un cultivador sereno',
          tone: 'triunfal',
          world: request,
        );
      case ActionOutcome.success:
        return _json(
          narration:
              'Lográs lo que buscabas: "${request.playerAction}". No fue '
              'sencillo, pero el mundo cede un poco ante tu voluntad.',
          choices: _choicesFrom(const [
            'Seguir avanzando por el sendero',
            'Detenerte a observar el entorno',
            'Poner a prueba lo aprendido',
          ]),
          deltas: const [
            {
              'type': 'exp',
              'key': 'exp',
              'value': 120,
              'operation': 'increment',
              'reason': 'Éxito en la acción intentada.',
            },
            {
              'type': 'flag',
              'key': 'progreso',
              'value': true,
              'operation': 'increment',
              'reason': 'El personaje avanzó por el sendero.',
            },
          ],
          imagePrompt: 'Un cultivador dando un paso firme en la niebla',
          tone: 'esperanzado',
          world: request,
        );
      case ActionOutcome.failure:
        return _json(
          narration:
              'Intentás "${request.playerAction}", pero el intento se '
              'deshace entre tus dedos. El qi se dispersa y quedás expuesto '
              'un instante de más.',
          choices: _choicesFrom(const [
            'Recomponerte y volver a intentarlo',
            'Cambiar de estrategia',
            'Retirarte a un lugar seguro',
          ]),
          deltas: const [
            {
              'type': 'exp',
              'key': 'exp',
              'value': 30,
              'operation': 'increment',
              'reason': 'Aprendizaje aun en la falla.',
            },
            {
              'type': 'resource',
              'key': 'qi',
              'value': -2,
              'operation': 'increment',
              'reason': 'El qi se dispersó con el intento fallido.',
            },
          ],
          imagePrompt: 'Qi disipándose en el aire frío de la montaña',
          tone: 'tenso',
          world: request,
        );
    }
  }

  /// Turns plain labels into the v2 `suggested_choices` shape (campaign-bible
  /// §18.5), deriving a stable-enough `id` from the label's position.
  List<Map<String, Object?>> _choicesFrom(List<String> labels) => [
        for (var i = 0; i < labels.length; i++)
          {'id': 'choice_$i', 'label': labels[i]},
      ];

  /// Builds the JSON contract string. Uses [jsonEncode] so the player action
  /// (arbitrary text) is always escaped correctly.
  String _json({
    required String narration,
    required List<Map<String, Object?>> choices,
    required List<Map<String, Object?>> deltas,
    required String imagePrompt,
    required String tone,
    required NarratorRequest world,
  }) {
    return jsonEncode({
      'narration': narration,
      'suggested_choices': choices,
      'proposed_state_deltas': deltas,
      'image_prompt': '$imagePrompt, ${world.world.imageStyleSuffix}',
      'tone': tone,
      'memory_facts': const <String>[],
      'node_status': 'active',
    });
  }

  String _fenced(String json) => '```json\n$json\n```';
}
