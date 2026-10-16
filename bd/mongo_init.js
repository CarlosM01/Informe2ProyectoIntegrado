// =====================================================================
// SGP-Kotoduo — Inicialización de la base no estructurada (MongoDB 8)
// Anexo C del Informe N.º 2, sección 6.4
// Uso:  mongosh "mongodb://localhost:27017/sgp_docs" --file mongo_init.js
//       (debe ejecutarse desde la carpeta bd/, junto a mongo_esquemas.json)
// =====================================================================
const fs = require('fs');
const def = JSON.parse(fs.readFileSync('mongo_esquemas.json', 'utf8')).colecciones;

for (const [nombre, c] of Object.entries(def)) {
  if (db.getCollectionNames().includes(nombre)) db.getCollection(nombre).drop();
  db.createCollection(nombre, {
    validator: c.validator,
    validationLevel: 'strict',
    validationAction: 'error',
  });
  for (const ix of c.indices) {
    const { key, ...opts } = ix;
    db.getCollection(nombre).createIndex(key, opts);
  }
  // EJSON convierte {"$date": ...} y {"$oid": ...} a tipos BSON reales
  db.getCollection(nombre).insertOne(EJSON.deserialize(c.ejemplo));
  print(`OK colección ${nombre}: validador, ${c.indices.length} índices y documento de ejemplo`);
}

// --- Idempotencia del relay outbox: reinsertar el mismo evento no lo duplica
const evento = EJSON.deserialize(def.bitacora_eventos.ejemplo);
const r = db.bitacora_eventos.updateOne({ _id: evento._id }, { $setOnInsert: evento }, { upsert: true });
print(`Reintento de evt-1842 -> insertados: ${r.upsertedCount} (esperado 0)`);

// --- El validador rechaza documentos mal formados (p. ej. tipo de evento inexistente)
try {
  db.bitacora_eventos.insertOne({
    _id: 'evt-999999', ts: new Date(), tipo: 'BORRADO_MASIVO',
    agregado: { tipo: 'orden_trabajo', id: 'x' },
    actor: { usuario_id: null, roles: [] }, payload: {},
  });
  print('ERROR: documento inválido aceptado');
} catch (e) {
  print(`OK validador rechazó documento inválido (code ${e.code})`);
}

// --- Consulta integrada: historial de una orden (lo que usa la vista "Detalle de orden")
const ordenId = '10000000-0000-0000-0000-000000000001';
print('Historial de la orden:');
db.bitacora_eventos
  .find({ orden_id: ordenId }, { _id: 1, ts: 1, tipo: 1, 'payload.siguiente_etapa': 1 })
  .sort({ ts: -1 })
  .forEach((d) => printjson(d));

print('Evidencias de la orden:');
db.evidencias_etapa
  .aggregate([
    { $match: { orden_id: ordenId } },
    { $group: { _id: '$tipo', total: { $sum: 1 }, bytes: { $sum: '$archivo.bytes' } } },
  ])
  .forEach((d) => printjson(d));

print('Uso de índice en la bandeja de notificaciones:');
const plan = db.notificaciones
  .find({ destinatario_id: '00000000-0000-0000-0000-000000000002', leida: false })
  .sort({ creada_en: -1 })
  .explain('queryPlanner').queryPlanner.winningPlan;
print(JSON.stringify(plan).includes('ix_bandeja') ? 'OK consulta resuelta con ix_bandeja' : JSON.stringify(plan));
