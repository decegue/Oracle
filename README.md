# Oracle con Docker

Script para instalar Docker y levantar una base de datos Oracle (imagen [`gvenzl/oracle-free`](https://hub.docker.com/r/gvenzl/oracle-free)) en un servidor Ubuntu 24.

## Requisitos

- Ubuntu 24
- Al menos 50 GB de disco
- Usuario con acceso `sudo`
- Si es un servidor en la nube (por ejemplo AWS): abrir el puerto `1521` solo para tu IP, nunca para todo Internet

## Instalación

```bash
git clone https://github.com/decegue/Oracle.git
cd Oracle
bash install-oracle-docker.sh
```

El script:

1. Actualiza el sistema e instala los requisitos previos.
2. Instala Docker (si no estaba instalado).
3. Añade tu usuario al grupo `docker`.
4. Elimina un contenedor anterior con el mismo nombre (el volumen de datos no se toca).
5. Te pide la contraseña de los usuarios `SYS` y `SYSTEM`.
6. Crea el contenedor y espera hasta que aparezca `DATABASE IS READY TO USE!`.
7. Muestra un resumen con los datos de conexión.

### Contraseña

La contraseña no está escrita en el script. Se pide por teclado, o se puede pasar como variable de entorno:

```bash
ORACLE_PASSWORD='TuContraseñaSegura' bash install-oracle-docker.sh
```

### Variables opcionales

| Variable         | Valor por defecto      | Descripción                            |
|------------------|------------------------|----------------------------------------|
| `CONTAINER_NAME` | `oracle19c`            | Nombre del contenedor                  |
| `ORACLE_IMAGE`   | `gvenzl/oracle-free`   | Imagen de Docker a usar                |
| `ORACLE_PORT`    | `1521`                 | Puerto del servidor                    |
| `VOLUME_NAME`    | `oracle-data`          | Volumen donde se guardan los datos     |
| `WAIT_TIMEOUT`   | `600`                  | Segundos máximos de espera al arrancar |

## Conectar desde SQL Developer

| Campo             | Valor                                                       |
|-------------------|-------------------------------------------------------------|
| Usuario           | `system`                                                    |
| Contraseña        | la que indicaste al instalar                                |
| Host              | `localhost` (o la IP de la máquina si SQL Developer está en otro equipo) |
| Puerto            | `1521`                                                      |
| Tipo de conexión  | Service Name                                                |
| Service Name      | `FREEPDB1` (base enchufable) o usando SID: `FREE` (contenedor raíz) |

## Manejo del contenedor

```bash
docker ps -a                   # ver contenedores
docker logs -f oracle19c       # ver el log
docker stop oracle19c          # parar
docker start oracle19c         # arrancar
docker restart oracle19c       # reiniciar
docker rm oracle19c            # eliminar (los datos siguen en el volumen)
```

Para usar `docker` sin `sudo`, cierra sesión y vuelve a entrar (abrir otra pestaña de terminal no basta), o ejecuta `newgrp docker` en la terminal actual.

## Guardar el contenedor como imagen (Docker Hub)

```bash
docker commit -m "Instalacion Oracle" -a "autor" oracle19c <usuario_docker_hub>/oracle_instalado
docker login -u <usuario_docker_hub>
docker push <usuario_docker_hub>/oracle_instalado
```

Para descargarla y lanzarla en otra máquina:

```bash
docker pull <usuario_docker_hub>/oracle_instalado
docker run -d --name oracle_instalado -p 1521:1521 <usuario_docker_hub>/oracle_instalado
```

## Notas

- El volumen `oracle-data` guarda los datos aunque borres el contenedor. Si reinstalas con un volumen existente, Oracle conserva la contraseña antigua y **ignora** `ORACLE_PASSWORD`. Para empezar de cero: `docker volume rm oracle-data` (borra todos los datos).
- La imagen `gvenzl/oracle-free` es Oracle Database Free, no la 19c, aunque el contenedor se llame `oracle19c` por defecto. Puedes cambiarlo con `CONTAINER_NAME`.

## Fuentes

- https://docs.docker.com/engine/install/ubuntu/
- https://hub.docker.com/r/gvenzl/oracle-free
