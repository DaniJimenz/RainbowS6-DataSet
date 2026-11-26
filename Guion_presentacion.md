# Guion · R6S Balance

## 1 · Portada

Bueno pues buenos días a todos yo soy dani y mi proyecto final responde a una pregunta que se hace cada temporada el equipo de r6s ¿está equilibrado el juego? 
## 2 · El dataset

Para el que no lo conozca r6s es un shooter táctico en el que se enfrentan cinco contra cinco: un equipo ataca un objetivo y el otro lo defiende, y cada jugador elige un operador con habilidades distintas.

El dato lo he sacado del datadump público de Ubisoft, a través de un csv de kaggle. Cada fila es un jugador en una ronda ( que operador llevaba, en que mapa y objetivo, su rango, si ganó, cuántas bajas hizo y si murió ) He cargado dos millones de filas que son unas 214.000 rondas.

Me he quedado con 16 de las 30 columnas ¿Por qué? porque las otras catorce, como armas o accesorios, no las usa ningún caso de uso. Si cargo columnas que nadie consume es coste de almacenamiento y cómputo además si mañana hicieran falta, el fichero original sigue en el stage.

Las fechas 12 y 13 de febrero de 2017 coinciden con la semana de lanzamiento de Velvet Shell en la que se introducen dos nuevos operadores que son Jackal y Mira , y eso da pie al tercer caso de uso.

## 3 · Casos de uso

Antes de modelar nada definí que necesita saber el cliente, que es el equipo de diseño que decide los parches. Salen tres preguntas.

Uno ( ¿qué operadores están desequilibrados y depende del rango de los jugadores? )

Dos ( ¿qué mapas favorecen al ataque o a la defensa? Y no solo el mapa: hasta el nivel de 
objetivo )

Tres ( el dataset es de la semana de lanzamiento de Jackal y Mira así que la pregunta natural es si llegaron rotos )

## 4 · Arquitectura

La arquitectura es medallion ( Bronze, Silver y Gold ). La elegí porque separa tres responsabilidades que cambian por motivos distintos. 

Bronze cambia cuando cambia la fuente
Silver, cuando cambian las reglas de limpieza
Gold, cuando cambian las preguntas de negocio. Si un día cambia una regla de negocio, no tengo que tocar la carga.

Subo el CSV a un stage interno de snowflake y lo cargo con COPY INTO en Bronze. A partir de ahí todo lo hace dbt.

Uso COPY INTO porque es idempotente ya snowflake recuerda qué ficheros ha cargado y si relanzo la carga no duplica datos.

Staging traduce - pone nombres de negocio y tipos correctos sin tocar filas. Es una vista, porque no transforma nada pesado: no ocupa espacio y siempre refleja Bronze. 

Silver limpia, deduplica y separa dos entidades. 

Gold es el modelo dimensional y las tablas que consume negocio. Silver y Gold son tablas, porque deduplicar dos millones de filas en cada consulta sería repetir el mismo trabajo una y otra vez.

## 5 · Bronze en Snowflake

En Bronze guardo el dato exactamente como llega. Todo es texto y es una decisión que tomé porque así la carga nunca falla por un valor raro y los tipos se deciden y se testean en dbt, donde hay control de versiones y tests. 

Cada fila lleva el fichero, la línea y el momento de carga. Eso será clave más adelante: el fichero y la línea son lo único que identifica cada fila, porque el dataset no trae ID de jugador.

## 6 · Silver: deduplicar no es borrar filas iguales

 Al analizar el CSV encontré 414 filas idénticas y lo fácil era borrarlas con un distinct pero al mirarlas 366 eran reclutas ( el recluta es el operador genérico y varios jugadores del mismo equipo pueden llevarlo ) Si dos reclutas hacen cero bajas y mueren, sus filas son iguales aunque sean personas distintas.

Solo 48 eran imposibles ya que el mismo operador estaba dos veces en el mismo equipo y la misma ronda, algo que el juego no permite. Así que deduplico por esa regla de negocio y los reclutas pasan siempre. Un DISTINCT habría borrado 366 jugadores reales.

Ahora, ¿por qué Silver tiene solo dos tablas? Porque en el dato de origen solo hay dos entidades reales, dos granos: el jugador en una ronda y la ronda. La ronda tiene atributos propios, como el ganador, la duración o el mapa, que en el CSV se repiten diez veces, una por jugador. Construirla en Silver es limpieza: consolido esos atributos en una fila y si no fueran coherentes entre jugadores, el test de unicidad fallaría. 

¿Y por qué no hay una tabla de operadores, de mapas o de rangos en Silver? Porque en el origen no son entidades con atributos propios: son códigos dentro de cada fila. Una tabla de operadores en Silver sería un SELECT DISTINCT sin limpieza ninguna, y eso ya es modelado dimensional, que es el trabajo de Gold. Tampoco hay tabla de partidas ( ninguna pregunta se responde por partida )

Y una regla más: Silver marca, no filtra. Reclutas, jugadores sin rango y duraciones imposibles quedan marcados con una columna, y cada caso de uso decide en Gold qué excluye. ¿Por qué? Porque lo que es ruido para una pregunta puede ser dato para otra. Los reclutas no sirven para comparar operadores, pero sí juegan rondas que cuentan para el balance de los mapas. Si los borrara en Silver, perdería rondas en el caso de uso 2.

Por último, el rango. Agrupo Platinum y Diamond en Platinum+. Diamond tiene 3.300 filas en todo el dataset, unas 110 por operador, muy lejos del mínimo de 1.000 rondas que exijo para fiarme de un win rate. Por separado, Diamond saldría siempre como "muestra insuficiente".

## 7 · Modelado: Gold en estrella

En gold tengo un esquema en estrella. Lo elegí porque es el formato que entiende cualquier herramienta de BI y cualquier analista: hechos con medidas, dimensiones con descripciones, y joins simples. Y cada decisión sale de los datos.

Primera: dos granos, dos tablas de hechos. Hay cosas de la ronda, como el ganador o la duración, y cosas del jugador como sus bajas. Si lo meto todo en una tabla, la duración de una ronda se repite diez veces y cualquier media o suma sale mal. Por eso hay fct_rounds, con una fila por ronda y fct_player_rounds con una por jugador y ronda y cada pregunta usa la de su grano ( mapas usa rondas y operadores usa jugadores )

Segunda: la dimensión de operadores tiene como clave operador más bando. Los treinta operadores normales son de un solo bando pero los reclutas juegan en los dos, y con solo el operador como clave la dimensión tendría duplicados.

Tercera: la dimensión de objetivos tiene mapa, modo y objetivo

Cuarta: el orden de los rangos no viene en el dato, así que lo mantengo como seed, un pequeño CSV versionado en el repositorio. 

Encima de la estrella están las tablas agregadas, las agg. ¿Por qué las he construido, si con la estrella ya se podría consultar todo? Por tres motivos.

El primero, que la lógica de negocio es lo difícil, no el group by. Para decir si un operador está desequilibrado hay que calcular la media de su bando en su rango con funciones de ventana, el margen de error estadístico y el estado final. Si eso lo hace cada analista en su herramienta, cada uno lo hará un poco distinto y saldrán dos cifras diferentes en la misma reunión. En la agg está definido una vez, versionado y testeado.

¿Y por qué el caso de uso 3 no tiene su propia agg? Porque es la misma pregunta que el caso 1 aplicada a dos operadores. Se responde filtrando agg_operator_balance por una columna, is_velvet_shell_operator. Una tabla aparte duplicaría la lógica y el día que cambie la fórmula habría que cambiarla en dos sitios.

Dos cosas que no hay

No hay dimensión de fecha ya que ninguno de los tres casos de uso analiza por fecha y el dataset cubre dos días. Sería una tabla de dos filas sin consumidores y si hubiera análisis temporal si la añadiría.

Y no hay snapshots ya que estos sirven para guardar la historia de un registro que cambia en origen ( un cliente que se muda, un producto que cambia de precio ) Aquí el origen son eventos: cada fila es una ronda que ya se jugó, y una ronda jugada no cambia nunca. Las dimensiones salen de los propios hechos, así que tampoco cambian. Un snapshot guardaría siempre la misma foto. 

## 8 · Calidad

Todos los tests se ejecutan en cada despliegue y me centro en los que protegen las cifras de los casos de uso. Son tres tipos.

Primero - en silver compruebo que un operador normal aparece solo una vez por equipo y ronda: es el test que demuestra que la deduplicación funciona. 

Segundo - la integridad referencial: cada fila de hechos tiene su operador, su rango, su objetivo y su ronda en la dimensión. Si una clave no casara, esa fila desaparecería con un join y cambiaría un win rate sin. 

Tercero - los valores aceptados en las columnas que lee negocio: el estado de balance solo puede ser Balanced, Overperforming, Underperforming o Low sample, y el rango solo puede ser uno de los grupos del seed.

En staging convierto los tipos con try_cast: un valor roto no tumba la ejecución, se convierte en nulo y lo detecta un test not_null. Es la otra mitad de la decisión de cargar Bronze como texto.

Y nada está escrito dos veces. Las fórmulas de porcentaje y de margen de desequilibrio viven en macros, porque se usan en las dos agg y tienen que dar exactamente lo mismo. Las reglas de negocio, como el umbral de dos puntos, el mínimo de rondas o la duración válida de una ronda, son variables del proyecto, porque son decisiones de negocio: si diseño decide que el umbral es tres puntos, se cambia en una línea sin tocar SQL.

## 9 · Entornos y CI/CD

Nadie construye producción a mano, porque un despliegue manual es un despliegue que algún día alguien hace mal. Trabajo en una rama y abro un pull request. El CI construye y testea solo lo que he modificado y lo que depende de ello, en esquemas temporales, y devuelve el check a GitHub. 

Al fusionar en main se lanza desarrollo y si va bien, dispara preproducción y esta dispara producción. Si algo falla, la cadena se para y un error nunca llega a negocio.

Para que cada entorno escriba en su sitio, sobrescribí la macro generate_schema_name: en desarrollo, preproducción y producción el esquema es el nombre limpio y en CI o en mi entorno personal lleva un prefijo. 

## 10 · Caso de uso 1: operadores

Primer resultado - el juego está bastante equilibrado ya que 26 de 30 operadores están a menos de dos puntos de la media de su bando.

Ojo con la referencia - la media no es el 50 %, sino casi el 52 % porque hay rondas con equipos incompletos. Si comparara con el 50 % casi todos los operadores parecerían fuertes. Por eso comparo siempre contra la media del bando.

Rook está justo en el límite() +2 puntos ) y diría que está en la frontera pero no que esté roto. Por debajo hay tres: Montagne, Blitz y Tachanka, el peor, a casi cinco puntos. Blitz y Tachanka son además los menos elegidos de su bando, en torno al 1 %.

Una precisión del criterio: para marcar desequilibrio no basta con pasar de 2 puntos. La diferencia también tiene que superar el margen de error estadístico al 95 %, que con pocas rondas es mayor y con mil rondas, ronda los tres puntos. 

## 11 · Caso de uso 2: mapas y objetivos

Segundo resultado - a nivel de mapa casi todo está equilibrado ( 10 de 16 mapas ) y el más desequilibrado, Bartlett está a cuatro puntos hacia la defensa.

Pero al bajar a objetivo las diferencias se triplican. En Yacht en el modo bomba, en cafetería, el ataque solo gana el 38 % de las rondas. En Chalet en Library se gana el 63 %. Son objetivos que se compensan entre sí y la media del mapa los esconde. Esto justifica haber modelado la dimensión de objetivos con mapa, modo y objetivo.

La tabla tiene tres niveles ( objetivo, mapa con modo y mapa ) ¿Por qué el intermedio? porque 66 de los 187 objetivos tienen menos de 500 rondas y salen como muestra insuficiente y el nivel de mapa con modo sí tiene muestra para concluir.

Aquí hubo una corrección importante. Cada objetivo se compara con la media de su modo, no con la global, porque el modo rehén ya favorece a la defensa ( el ataque gana el 46 % frente al 50 % de los otros modos ) con la media global, Bank Vault salía como el peor objetivo, a menos trece puntos frente a su modo se queda en menos nueve y medio. 

## 12 · Caso de uso 3: Velvet Shell

Tercer resultado - Jackal y Mira no llegaron rotos. Los dos están a menos de dos puntos de su bando en todos los rangos y con muestra suficiente ( más de mil rondas en cada rango ) Mira está prácticamente en la media exacta 

Lo interesante es Jackal ya que si miras solo su win rate, sube del 44 % en Copper al 55 % en Platinum y alguien puede pensar que es un operador fuerte en manos expertas. Pero la media de los atacantes sube exactamente igual porque los jugadores de rango alto ganan más con cualquier operador. Dentro de cada rango Jackal está siempre en la media.

Si no hubiese comparado dentro de cada rango habría sacado una conclusión falsa y habría recomendado un nerf innecesario. Y Jackal se eligió en casi el 10 % de las rondas de ataque ya que simplemente fue más popular pero no más fuerte.

## 14 · Gracias



