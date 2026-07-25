# NARRATIVE_VOICE.md — Guía de voz narrativa de Aetherbook

Este documento es la referencia canónica y durable de **cómo debe sonar
toda narración de Aetherbook** — el prompt compartido del narrador, el
`system_prompt` de cada mundo, y el contenido literal escrito a mano en
las campañas curadas/híbridas. No es una nota de sesión: cualquier trabajo
futuro sobre narración, mío o de otra persona, debe leer esto primero.

Referenciado desde `CLAUDE.md` §1, al lado del GDD.

---

## 1. Regla central: tuteo, nunca voseo

Toda la narración se dirige al jugador (y, dentro de los diálogos, entre
personajes) en **español neutro con tuteo** — "tú", "tienes", "eres" —
**nunca** en voseo rioplatense — "vos", "tenés", "sos". Esto vale para:

- El texto que efectivamente lee el jugador (narración, diálogos, opciones).
- Las instrucciones que le damos a la IA (el prompt en sí también debe
  estar en tuteo/neutro; no tiene sentido pedirle "español neutro" en un
  prompt escrito en voseo).

El protagonista sigue narrado en **segunda persona** — eso es estructural
al motor, no cambia — pero conjugado en tuteo: "sientes", "te preguntas",
"puedes", "quieres", nunca "sentís", "te preguntás", "podés", "querés".

### 1.1 Tabla de conversión (verbos que más aparecen en el contenido actual)

La conversión voseo→tuteo **no es un reemplazo de "vos" por "tú"** — es un
cambio real de conjugación. Esta tabla cubre los verbos que más se repiten
en las historias de Aetherbook, presente indicativo e imperativo
afirmativo (el imperativo negativo ya coincide en ambos: "no te vayas" es
igual en voseo y en tuteo, no hace falta tocarlo).

| Verbo | Voseo (presente) | Tuteo (presente) | Voseo (imperativo) | Tuteo (imperativo) |
|---|---|---|---|---|
| ser | sos | eres | (no se usa) | sé |
| tener | tenés | tienes | tené | ten |
| poder | podés | puedes | — | — |
| querer | querés | quieres | queré | quiere |
| saber | sabés | sabes | sabé | sabe |
| hacer | hacés | haces | hacé | haz |
| decir | decís | dices | decí | di |
| venir | venís | vienes | vení | ven |
| mirar | mirás | miras | mirá | mira |
| escuchar | escuchás | escuchas | escuchá | escucha |
| sentir | sentís | sientes | sentí | siente |
| dejar | dejás | dejas | dejá | deja |
| quedar(se) | quedás / quedate | quedas / quédate | quedate | quédate |
| entrar | entrás | entras | entrá | entra |
| salir | salís | sales | salí | sal |
| volver | volvés | vuelves | volvé | vuelve |
| seguir | seguís | sigues | seguí | sigue |
| buscar | buscás | buscas | buscá | busca |
| contar | contás | cuentas | contá | cuenta |
| pensar | pensás | piensas | pensá | piensa |
| notar | notás | notas | notá | nota |
| girar | girás | giras | girá | gira |
| cruzar | cruzás | cruzas | cruzá | cruza |
| respirar | respirás | respiras | respirá | respira |
| llegar | llegás | llegas | llegá | llega |
| caminar | caminás | caminas | caminá | camina |
| correr | corrés | corres | corré | corre |
| gritar | gritás | gritas | gritá | grita |
| llevar | llevás | llevas | llevá | lleva |
| agarrar | agarrás | agarras | agarrá | agarra |
| acordarse | acordate | — | acordate | acuérdate |
| fijarse | fijate | — | fijate | fíjate |

**Verbos que NO cambian** (coinciden en voseo y tuteo — no los "corrijas"
de más): estar (**estás** en ambos), ir (**vas** en ambos), ver (**ves**
en ambos), dar (**das** en ambos).

**Pronombres y clíticos**:
- "vos" → "tú" (sujeto). "a vos" → "a ti". "con vos" → "contigo".
- "te" (objeto/reflexivo) **no cambia** — es igual en voseo y tuteo.
- "tu / tus" (posesivo) **no cambia** — es igual en ambos.
- "vos mismo/misma" → "tú mismo/misma".

### 1.2 Registro entre personajes: tú vs. usted

El protagonista siempre es "tú" para el narrador. Pero **entre personajes**,
dentro de los diálogos, el registro puede subir a "usted" cuando hay
distancia social real: jerarquía militar o institucional, una autoridad
religiosa o política, un desconocido tratado con formalidad deliberada, un
subordinado dirigiéndose a su superior. Dos personajes que se conocen bien
o que son pares (aliados, compañeros de generación, amigos) se tutean. Esto
no es una regla rígida por mundo sino de relación: un mismo personaje puede
tutear a unos y hablar de usted a otros según a quién se dirija.

---

## 2. Referencia de prosa: Dan Brown (traducción al español)

El usuario compartió fragmentos de una traducción al español de una novela
de Dan Brown como referencia de tono. Lo que sigue es mi propio análisis de
los patrones que observé ahí — no una transcripción del texto, que está
protegido por derechos de autor — traducido a reglas aplicables a
Aetherbook.

- **Diálogo puntuado con raya y acotación breve.** "—Frase dicha por el
  personaje —dijo Fulano—, resto de la frase." La acotación ("dijo",
  "preguntó", "replicó", "exclamó") es corta y casi nunca lleva adverbio
  pegado ("dijo secamente" es la excepción, no la norma); el verbo solo ya
  transmite el tono si el diálogo está bien escrito.
- **Ritmo de frase muy irregular.** Frases de tres o cuatro palabras
  ("Vittoria estaba confusa.") conviven con otras largas, de sintaxis
  subordinada, que acumulan información concreta antes de cerrar. Nunca dos
  frases seguidas del mismo largo.
- **Descripción económica, verbos precisos antes que adjetivos
  acumulados.** Un personaje no está "profundamente nervioso y con el
  corazón latiéndole con fuerza" — hace algo concreto (consulta el reloj,
  aprieta el hombro de alguien, se le corta la voz a mitad de frase) y ese
  gesto solo ya comunica el estado interno.
- **La tensión se construye con detalle concreto, no nombrando la
  emoción.** En vez de decir que una escena es tensa, la prosa describe el
  reloj que se consulta, el silencio que se corta, la orden que no llega a
  tiempo — y deja que el lector arme la tensión.
- **Los cierres de escena no siempre resuelven.** Una escena puede terminar
  en una orden dada, una pregunta sin responder, un gesto a medio hacer —
  no hace falta una frase de cierre prolija ni una conclusión redonda.
- **El registro formal aparece cuando corresponde.** Diálogos entre
  personajes de distinta jerarquía o distancia social usan "usted" con
  naturalidad, sin que se sienta acartonado — ver §1.2.

Esta referencia es de **ritmo y textura**, nunca de frases o construcciones
literales — no copiar, adaptar el patrón.

---

## 3. Checklist rápido

Antes de dar por terminada cualquier narración (prompt o contenido
autoral):

- [ ] Cero apariciones de "vos" como sujeto.
- [ ] Cero conjugaciones voseantes (repasar la tabla de §1.1 si hay duda).
- [ ] "Usted" usado donde hay distancia social real entre personajes (§1.2),
      no en cada diálogo por default.
- [ ] Al menos una frase muy corta y una frase larga y compleja conviviendo
      en el mismo pasaje — nunca ritmo uniforme.
- [ ] Ningún cliché de la lista ya prohibida en `HUMAN_STYLE_INSTRUCTION`
      ("el aire se cargó de tensión", "una mezcla de emociones", etc.).
- [ ] El cierre de la escena no resuelve de más — no todo termina en una
      frase prolija.
