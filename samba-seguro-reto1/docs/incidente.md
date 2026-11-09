# Incidente simulado — Dana no puede guardar en RRHH

Caso propuesto por la guía (hito 7): un usuario no puede escribir donde "debería tener acceso".
Hay que determinar si es **permiso Linux**, **permiso Samba** o **cuota agotada**.

## Estado inicial
- Dana sube `antes_incidente.txt` a `rrhh` sin problema.
- `getfacl /srv/samba/rrhh` → `group::rwx`, `mask::rwx`.
- Respaldo previo: `getfacl -p /srv/samba/rrhh > ~/acl_rrhh_antes.txt`.

## Falla provocada
```bash
sudo chmod g-w /srv/samba/rrhh
```
En una carpeta con ACL, `chmod` sobre el grupo **no cambia `group::` sino la máscara**.

## Síntoma
Al subir `durante_incidente.txt`, Samba responde `NT_STATUS_ACCESS_DENIED`.
Usuario, contraseña y conexión de Dana no cambiaron.

## Hipótesis y diagnóstico
| Hipótesis | Comando | Resultado |
|---|---|---|
| H1. Dana salió del grupo `rrhh` | `id dana` | Descartada: sigue en `rrhh` |
| H2. Samba la bloquea (`valid users` / `write list`) | `sudo -u dana touch /srv/samba/rrhh/diagnostico_rrhh.txt` y revisión de `smb.conf` | Descartada: falla también directo en Linux, sin pasar por Samba; `smb.conf` sin cambios |
| H3. Cuota agotada | `sudo repquota -uv /srv/samba` | Descartada: 8 KiB de 204800; además una cuota llena daría `NT_STATUS_DISK_FULL` |
| H4. Permisos efectivos (ACL) | `getfacl /srv/samba/rrhh` | **Confirmada**: `group::rwx #effective:r-x`, `mask::r-x` |

Regla rápida: `ACCESS_DENIED` → permisos · `DISK_FULL` → cuota · fallo en `tree connect` → `valid users`.

## Causa raíz
La máscara ACL quedó en `r-x`. La máscara es el tope de las entradas de usuario y grupo nombradas y del
grupo dueño: aunque `group::rwx` conservaba la escritura, la máscara la anulaba. `ls -l` solo muestra un `+`.

## Solución
```bash
sudo setfacl --restore="$HOME/acl_rrhh_antes.txt"
# alternativa: sudo setfacl -m m::rwx /srv/samba/rrhh
```
No se tocaron usuarios, grupos, cuotas ni `smb.conf`.

## Verificación
- `getfacl` vuelve a mostrar `mask::rwx`.
- Dana sube `despues_incidente.txt` con éxito.
- Tras reiniciar el servidor: `smbd`, `tailscaled` y `ssh.socket` activos, `/srv/samba` montado con cuotas, Serve operando.
