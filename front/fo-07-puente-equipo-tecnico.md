# El Puente con el Equipo Técnico

**Ejercicio FO-7 - 15 minutos**

*Cierre del track. Se hace en conjunto con el track técnico.*

---

## Objetivo

Ver en vivo qué añade Claude Code sobre lo que tú acabas de aprender, y salir con una petición concreta y bien formulada para el equipo técnico.

## Contexto

Has montado un espacio de trabajo con contexto, has publicado una skill, has encargado un pipeline de cuatro etapas y has conectado un servicio externo. Todo sin tocar una línea de código.

Quedan dos cosas por hacer: entender **dónde está el techo** de lo que puedes montar solo, y saber **cómo se pide** lo que está por encima.

---

## Paso 1: La Demo — un Hook Bloqueando de Verdad

*(La corre alguien del track técnico, en su pantalla. Tú miras.)*

Van a hacer dos cosas seguidas:

**1. Una regla en prosa.** En su `CLAUDE.md`, el equivalente de tus instrucciones:
```markdown
- Nunca ejecutes comandos que borren archivos de forma recursiva
```
Le piden que borre algo. Casi siempre se niega. Bien.

**2. La misma regla como hook.** Un script de 15 líneas que se ejecuta **antes** de cada comando, mira lo que va a correr y devuelve "bloqueado" si encaja con un patrón peligroso.

Le vuelven a pedir lo mismo, esta vez insistiendo. Observa la diferencia:

```
BLOCKED: Comando peligroso detectado: rm -rf
```

Ese mensaje no lo escribió el modelo. Lo escribió un script que corrió pase lo que pase. **El modelo ni llegó a tener la oportunidad de decidir.**

Es exactamente el experimento que hiciste en FO-4, con el final que a ti te faltaba.

---

## Paso 2: Dónde Vive Cada Cosa

Con la demo fresca, la tabla completa del sistema:

| Necesidad | Dónde vive | Quién lo monta |
|---|---|---|
| Contexto de negocio, métricas, tono | Instrucciones del proyecto / `CLAUDE.md` | **Tú** |
| Un procedimiento que repites | Skill | **Tú**, o te la provisionan |
| Trabajo largo por etapas | Encargo en Cowork | **Tú** |
| Conectar a un servicio conocido | Connector del catálogo | **Tú** |
| Conectar a una API interna de la empresa | Connector a medida | **Equipo técnico** |
| Una regla que debe cumplirse **siempre** | Hook | **Equipo técnico** |
| Registro auditable de todo lo que se hizo | Hook de logging | **Equipo técnico** |
| Que todo el equipo tenga lo mismo sin instalarlo | Provisión desde la organización | **Equipo técnico** |

La línea divisoria es limpia: **tú montas lo que afecta a tu trabajo; ellos montan lo que tiene que valer para todos o no puede fallar nunca.**

---

## Paso 3: Cómo te Llega lo que Pides

Importa saberlo, porque determina qué tiene sentido pedir:

| Lo que ellos publican | ¿Te llega a Cowork y Chat? |
|---|---|
| Una **Skill** desde *Organization settings → Skills* | **Sí.** Aparece en tu Customize, activada por defecto |
| Un **Connector** desde *Organization settings → Connectors* | **Sí.** Disponible para añadir |
| Un **Plugin** desde *Organization settings → Plugins* | **No.** Los plugins solo llegan a Claude Code |
| Un archivo en un repositorio de git | **No.** Tu superficie no lee repositorios |

Traducción práctica para tu petición: **pide skills y connectors.** Si te ofrecen un plugin o "algo en el repo", pídeles que te lo entreguen como skill provisionada, o no lo vas a ver nunca.

---

## Paso 4: Redactar la Petición

Saca las peticiones que escribiste en el Paso 6 de FO-4 y complétalas con lo que ya sabes:

```
PETICIÓN AL EQUIPO TÉCNICO

Qué necesito:   [en una frase, en lenguaje de negocio]
Tipo:           [garantía / skill / connector]
Hoy lo hago:    [cómo lo resuelves ahora, y qué falla]
Si falla:       [impacto real, con números si puedes]
Entrégamelo:    [skill provisionada / connector / demo]
```

Ejemplo completo:

```
PETICIÓN AL EQUIPO TÉCNICO

Qué necesito:   Que ningún archivo de data/ se modifique ni se borre nunca
Tipo:           Garantía
Hoy lo hago:    Una regla en las instrucciones. En FO-4 comprobé que cede
                si insisto, y yo insisto los viernes
Si falla:       Perdemos el export original; Sistemas tarda 2 días en
                regenerarlo y el reporte semanal sale tarde
Entrégamelo:    Como sea, es cosa vuestra — solo necesito saber que aplica
```

```
PETICIÓN AL EQUIPO TÉCNICO

Qué necesito:   Consultar el GMV del datawarehouse sin exportar a CSV
Tipo:           Connector
Hoy lo hago:    Pido el export a Sistemas, lo bajo, lo meto en data/.
                Un día de retraso y el dato ya está viejo
Si falla:       El reporte semanal siempre va con datos de la semana pasada
Entrégamelo:    Connector provisionado a la organización, solo lectura
```

**Verificación:** dáselas a alguien del track técnico y que te diga si puede estimarlas sin preguntarte nada más. Si tiene que preguntarte algo, la petición no estaba terminada.

---

## Checklist Final del Track

Marca lo que puedas demostrar, no lo que recuerdes haber leído:

**Lo que montaste**
- [ ] Un proyecto con contexto de negocio que responde sin explicárselo (FO-1)
- [ ] Alcance y permisos elegidos a conciencia (FO-2)
- [ ] Una skill publicada que se dispara sola con tus frases (FO-3)
- [ ] Un pipeline de cuatro etapas verificado por conteos (FO-5)
- [ ] Un connector conectado y usado para cerrar el círculo (FO-6)

**Lo que entendiste**
- [ ] Por qué una instrucción no es una garantía, y las tres garantías que sí tienes (FO-4)
- [ ] Cuándo un procedimiento debe dejar de ser un prompt y volverse skill
- [ ] Que el contenido que viene de fuera es dato, nunca instrucción
- [ ] Que las skills y los connectors te llegan de la organización; los plugins no

**Lo que te llevas**
- [ ] 3-4 peticiones escritas y validadas con el equipo técnico

---

## El Recorrido Completo

```
FO-1  Contexto      →  Claude sabe para quién trabaja
FO-2  Alcance       →  Claude ve lo justo, con la autonomía justa
FO-3  Skill         →  Tu procedimiento, guardado e invocable
FO-4  Límites       →  Sabes qué puedes confiarle sin supervisión
FO-5  Delegación    →  Encargas trabajo largo y lo puedes auditar
FO-6  Integración   →  Conectado a tus herramientas reales
FO-7  Escalada      →  Sabes qué pedir y cómo pedirlo
```

Es el mismo recorrido del track técnico. Ellos lo hicieron en archivos versionados; tú en una interfaz. El sistema que sale al final es uno solo — y el reporte semanal que produce es el mismo.

## Tip Final

La trampa habitual después de un taller así es volver al trabajo y usar Claude exactamente como antes: una pregunta suelta cada vez.

El cambio real está en una sola costumbre: **cuando te descubras escribiendo el mismo contexto o el mismo procedimiento por tercera vez, párate y guárdalo.** Contexto → instrucciones del proyecto. Procedimiento → skill. Es todo el track en una frase.
