const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/https");
const logger = require("firebase-functions/logger");
const fetch = require("node-fetch");

// Giới hạn tối đa 10 instance / function
setGlobalOptions({maxInstances: 10});

// Proxy OSRM để Flutter Web không bị CORS
exports.routeOsrm = onRequest(async (req, res) => {
  // CORS cho web
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  // Preflight OPTIONS
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  const coordStr = req.query.coordStr;
  if (!coordStr) {
    res.status(400).json({error: "missing_coordStr"});
    return;
  }

  try {
    const url =
      "https://router.project-osrm.org/route/v1/driving/" +
      coordStr +
      "?overview=full&geometries=polyline&steps=false";

    logger.info("Calling OSRM", {coordStr});

    const r = await fetch(url);
    const data = await r.json();

    res.json(data); // trả nguyên JSON OSRM
  } catch (e) {
    logger.error("OSRM error", e);
    res.status(500).json({error: "osrm_error"});
  }
});
