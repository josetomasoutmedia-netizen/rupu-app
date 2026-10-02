#!/bin/bash
cd "$(dirname "$0")"
echo "Rüpü corriendo en http://localhost:8973/rupu.html  (deja esta ventana abierta; ciérrala para apagarlo)"
exec python3 -m http.server 8973
