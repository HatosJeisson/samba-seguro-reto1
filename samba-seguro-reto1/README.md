# Reto 1 — Almacenamiento seguro y auditoría con Samba

Proyecto final de **Sistemas Operacionales (12997)** · Universidad El Bosque · 2026-2
Docente: Ing. Samuel Galindo Pinzón

**Equipo:** Jeisson Elías Herreño Silva · Sergio Alejandro Pastran Castellanos · Camilo Peláez Pérez · Kevin Tunjuelo Arévalo

## Qué es

Servidor de archivos Samba 4.23 sobre Ubuntu Server 26.04 LTS para una empresa con tres departamentos
(Contabilidad, RRHH y Gerencia). Cada área solo ve y modifica lo suyo, cada usuario tiene una cuota de
espacio y todas las operaciones sobre archivos quedan auditadas en el journal.

| Usuario | Grupo | Contabilidad | RRHH | Gerencia | Cuota |
|---|---|---|---|---|---|
| laura | contabilidad | Lectura y escritura | — | — | 150 MiB |
| dana | rrhh | — | Lectura y escritura | — | 200 MiB |
| carla | gerencia | Solo lectura | Solo lectura | Lectura y escritura | 300 MiB |

## Arquitectura

```
Cliente Windows (100.79.91.73) ──┐               ┌─ servidor-samba (100.90.231.14)
  SMB 445 + SSH 22               │  Tailscale    │   Tailscale Serve :445 → 127.0.0.1:445
                                 ├──  (VPN)  ────┤   smbd (valid users / write list)
nodob, Ubuntu (100.122.147.118) ─┘               │   Permisos Linux + ACL (2770, mask)
  solo SMB 445 (mount.cifs)                      │   Cuotas ext4 en /srv/samba
                                                 └─  full_audit → journalctl -t smbd_audit
```

| Puerto | Protocolo | Exposición |
|---|---|---|
| 445/TCP | SMB 3.1.1 | Solo por `tailscale0` |
| 22/TCP | SSH | Solo por `tailscale0` y desde 100.79.91.73 |

## Contenido del repositorio

| Carpeta | Contenido |
|---|---|
| `config/samba/` | `smb.conf` efectivo (salida de `testparm -s`) |
| `config/ssh/` | `01-samba-hardening.conf` y valores efectivos de `sshd -T` |
| `config/ufw/` | Reglas finales de UFW |
| `config/fstab/` | Montaje persistente del disco de datos con cuotas |
| `config/tailscale/` | Estado de Tailscale Serve |
| `permisos/` | ACL de cada carpeta (`getfacl -p`), incluido el respaldo usado en el incidente |
| `cuotas/` | Reporte `repquota -uv` |
| `docs/` | Bitácora técnica e incidente simulado |
| `scripts/` | Script que exporta todos estos archivos desde el servidor |
| `evidencias/` | Extractos de auditoría y estado de servicios |

Documentos entregados en el Aula Virtual: informe técnico, ficha técnica, presentación y Anexo C (evidencias fotográficas).

## Cómo reproducir los puntos clave

```bash
# Permisos: Dana no puede entrar a Contabilidad
smbclient //100.90.231.14/contabilidad -U dana -c 'ls'      # NT_STATUS_ACCESS_DENIED

# Cuotas
sudo repquota -uv /srv/samba

# Auditoría
journalctl -t smbd_audit --since "1 hour ago"

# Montaje desde el segundo nodo
sudo mount -t cifs //100.90.231.14/contabilidad /mnt/contabilidad \
  -o username=laura,vers=3.1.1,uid=$(id -u),gid=$(id -g)
```

## Incidente simulado (resumen)

`chmod g-w /srv/samba/rrhh` cambió la **máscara ACL** a `r-x` y Dana recibió `NT_STATUS_ACCESS_DENIED`.
Se descartaron grupo (`id dana`), cuota (`repquota`) y Samba (`sudo -u dana touch` falla también en Linux);
`getfacl` mostró `group::rwx #effective:r-x`. Solución: `setfacl --restore` desde el respaldo previo.
Detalle completo en [`docs/incidente.md`](docs/incidente.md).

## Seguridad de este repositorio

No se publican contraseñas, llaves privadas, la base de usuarios de Samba (`passdb.tdb`, `secrets.tdb`)
ni archivos de credenciales de `mount.cifs`.
