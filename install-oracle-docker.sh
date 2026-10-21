#!/bin/bash

# ============================================
# SCRIPT DE INSTALACIÓN DE ORACLE DATABASE CON DOCKER
# ============================================
# Este script instala Docker y levanta Oracle Database Free
# (imagen gvenzl/oracle-free) en un contenedor con datos persistentes.
# Sistema: Ubuntu 24
# Prerequisitos: Acceso sudo y al menos 50 GB de disco
# ============================================

set -e # Detener el script si hay algún error

# --------------------------------------------
# VARIABLES (se pueden sobrescribir desde fuera)
# Ejemplo: CONTAINER_NAME=mi-oracle bash install-oracle-docker.sh
# --------------------------------------------
CONTAINER_NAME="${CONTAINER_NAME:-oracle19c}"
ORACLE_IMAGE="${ORACLE_IMAGE:-gvenzl/oracle-free}"
ORACLE_PORT="${ORACLE_PORT:-1521}"
VOLUME_NAME="${VOLUME_NAME:-oracle-data}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-600}"

echo "============================================"
echo "INICIANDO INSTALACIÓN DE ORACLE CON DOCKER"
echo "============================================"
echo ""

# ============================================
# 1. ACTUALIZAR SISTEMA E INSTALAR REQUISITOS
# ============================================
echo "[1/7] Actualizando sistema e instalando requisitos previos..."

sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y ca-certificates curl

echo ""

# ============================================
# 2. INSTALAR DOCKER
# ============================================
if command -v docker >/dev/null 2>&1; then
  echo "[2/7] Docker ya está instalado, se omite la instalación."
else
  echo "[2/7] Agregando clave GPG y repositorio de Docker..."

  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  echo "[2/7] Instalando Docker..."

  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

echo "[2/7] Iniciando y habilitando Docker..."

sudo systemctl start docker
sudo systemctl enable docker

echo "[2/7] Verificando instalación de Docker..."

sudo docker --version

echo ""

# ============================================
# 3. PERMITIR USAR DOCKER SIN SUDO
# ============================================
echo "[3/7] Añadiendo el usuario $USER al grupo docker..."

sudo usermod -aG docker "$USER"

echo "[3/7] Nota: para usar docker sin sudo hay que cerrar sesión y volver a entrar"
echo "      (o ejecutar 'newgrp docker' en la terminal). Este script usa sudo, así que no le afecta."
echo ""

# ============================================
# 4. LIMPIAR CONTENEDOR EXISTENTE (OPCIONAL)
# ============================================
echo "[4/7] Limpiando contenedor existente (si lo hay)..."

sudo docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

echo "[4/7] El volumen $VOLUME_NAME (datos de la base de datos) NO se borra."
echo ""

# ============================================
# 5. CONTRASEÑA DE SYS Y SYSTEM
# ============================================
# Si no se pasa por variable de entorno, se pide por teclado
# (así no queda escrita en el repositorio).
echo "[5/7] Configurando contraseña de los usuarios SYS y SYSTEM..."

if [ -z "${ORACLE_PASSWORD:-}" ]; then
  while true; do
    read -r -s -p "Contraseña para SYS y SYSTEM: " ORACLE_PASSWORD < /dev/tty
    echo ""
    read -r -s -p "Repite la contraseña: " ORACLE_PASSWORD_CONFIRM < /dev/tty
    echo ""

    if [ -z "$ORACLE_PASSWORD" ]; then
      echo "La contraseña no puede estar vacía."
    elif [ "$ORACLE_PASSWORD" != "$ORACLE_PASSWORD_CONFIRM" ]; then
      echo "Las contraseñas no coinciden."
    else
      break
    fi
  done
fi

echo ""

# ============================================
# 6. CREAR CONTENEDOR DE ORACLE DATABASE
# ============================================
echo "[6/7] Creando contenedor de Oracle (la primera vez descarga la imagen)..."

sudo ORACLE_PASSWORD="$ORACLE_PASSWORD" docker run -d \
  --name "$CONTAINER_NAME" \
  -p "$ORACLE_PORT":1521 \
  -e ORACLE_PASSWORD \
  -v "$VOLUME_NAME":/opt/oracle/oradata \
  --restart unless-stopped \
  "$ORACLE_IMAGE"

echo "[6/7] Esperando a que la base de datos esté lista (puede tardar un par de minutos)..."

ELAPSED=0
until sudo docker logs "$CONTAINER_NAME" 2>&1 | grep -q "DATABASE IS READY TO USE!"; do
  if ! sudo docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    echo "[6/7] ✗ ERROR: el contenedor se ha detenido. Últimas líneas del log:"
    sudo docker logs --tail 30 "$CONTAINER_NAME"
    exit 1
  fi

  if [ "$ELAPSED" -ge "$WAIT_TIMEOUT" ]; then
    echo "[6/7] ✗ ERROR: la base de datos no estuvo lista tras ${WAIT_TIMEOUT}s."
    echo "      Revisa el log con: docker logs $CONTAINER_NAME"
    exit 1
  fi

  sleep 10
  ELAPSED=$((ELAPSED + 10))
  echo "      ... esperando (${ELAPSED}s)"
done

echo "[6/7] ✓ Oracle Database iniciada correctamente"
echo ""

# ============================================
# 7. VERIFICACIÓN FINAL
# ============================================
echo "============================================"
echo "VERIFICACIÓN FINAL"
echo "============================================"
echo ""

echo "Contenedores en ejecución:"
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "Volumen de datos:"
sudo docker volume ls --filter name="$VOLUME_NAME"
echo ""

echo "============================================"
echo "✓ INSTALACIÓN COMPLETADA EXITOSAMENTE"
echo "============================================"
echo ""
echo "Datos de conexión (SQL Developer):"
echo "  Usuario:      system"
echo "  Contraseña:   la que has indicado"
echo "  Host:         localhost (o la IP de la máquina)"
echo "  Puerto:       $ORACLE_PORT"
echo "  Service Name: FREEPDB1   (base enchufable, donde se trabaja normalmente)"
echo "  SID:          FREE       (contenedor raíz)"
echo ""
echo "Para ver los logs:"
echo "  docker logs -f $CONTAINER_NAME"
echo ""
echo "Para detener el contenedor:"
echo "  docker stop $CONTAINER_NAME"
echo ""
echo "Para iniciar el contenedor:"
echo "  docker start $CONTAINER_NAME"
echo ""
echo "Para reiniciar el contenedor:"
echo "  docker restart $CONTAINER_NAME"
echo ""
echo "============================================"
