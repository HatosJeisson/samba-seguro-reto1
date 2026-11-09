# Bitácora técnica

Hora del servidor (UTC-5). Versión completa en el Anexo A del informe.

| Fecha / hora | Actividad y comandos | Resultado o error | Solución / nota |
|---|---|---|---|
| 24-oct 21:30 | Instalación de Tailscale; `tailscale up`, `ip a` | IP 100.90.231.14 | — |
| 24-oct 21:38 | `apt install samba`; `smbd --version`; `systemctl status smbd` | Samba 4.23.6 activo en 0.0.0.0:445 | Exposición corregida después (Serve + localhost) |
| 24-oct 21:45 | `groupadd contabilidad/rrhh/gerencia`; `useradd -M -s /usr/sbin/nologin` | GID/UID 1001-1003 | — |
| 24-oct 21:51 | `smbpasswd -a` ×3; `mkdir -p /srv/samba/{...}`; `chown root:<grupo>`; `chmod 2770` | `pdbedit -L` lista los 3 | — |
| 24-oct 21:55 | Copia `smb.conf.bak`; edición de recursos; `testparm`; restart smbd | Loaded services file OK | — |
| 24-oct 22:05 | `setfacl -m u:carla:rx` y `d:u:carla:rx` en contabilidad y rrhh | Carla: `ls` OK, `touch` denegado | Comportamiento esperado |
| 24-oct 22:12 | smbclient: Laura `put factura_prueba.txt`; Dana `ls`; Carla `get/put` | Dana `ACCESS_DENIED`; Carla `LOGON_FAILURE` | Contraseña mal digitada; reintento OK |
| 24-oct 22:30 | `df -T /srv/samba` | En /dev/sda2, sin cuotas | Se decide disco dedicado |
| 24-oct 22:52 | Disco sdb 2 GB; `mkfs.ext4 -O quota -L SAMBA_DATOS`; montaje temporal; `cp -a` | Datos y ACL copiados | smbd detenido durante la copia |
| 24-oct 23:00 | Montaje en /srv/samba; fstab (copia .bak); `findmnt --verify`; `quotaon` | Avisos tmpfs en quota | Avisos inofensivos |
| 24-oct 23:10 | `setquota -u` laura 153600, dana 204800, carla 307200 | repquota con límites | — |
| 24-oct 23:22 | Prueba de cuota con `dd` de 100 y 60 MiB | `NT_STATUS_DISK_FULL` | Archivos de prueba eliminados |
| 25-oct 00:05 | smbclient tras activar full_audit | `NT_STATUS_CONNECTION_DISCONNECTED` | smbd reiniciándose; reintento OK |
| 25-oct 00:48–01:00 | full_audit en los 3 recursos; `journalctl -t smbd_audit` | Eventos de laura, dana y carla | — |
| 25-oct 01:10 | `ufw allow in on tailscale0 to any port 445`; `tailscale serve --bg --tcp=445 tcp://127.0.0.1:445` | Serve activo | — |
| 25-oct 17:55 | Windows: `Test-NetConnection`; `net use` laura y carla | Laura escribe; Carla denegada | — |
| 25-oct 20:43 | nodob: `tailscale ping`; smbclient laura/dana; `mount.cifs`; escritura laura y carla | Permisos respetados | — |
| 25-oct 20:52 | Instalación de SSH; `sshd -T` | root prohibit-password, password yes | Se endurece |
| 25-oct 21:05 | `01-samba-hardening.conf`; ufw 22 desde 100.79.91.73; llave ed25519 | Login solo con llave | — |
| 26-oct 20:44–20:54 | Incidente: `getfacl -p` (respaldo); `chmod g-w`; diagnóstico; `setfacl --restore` | `ACCESS_DENIED` → resuelto | Ver `incidente.md` |
| 26-oct 21:30 | Reinicio y verificación de persistencia | Todo activo | — |
| 26-oct 21:40 | `ss -tulnp`: pcsd (2224), NFS (2049), rpcbind | Servicios ajenos al reto | stop + disable; borrado de reglas UFW |
| 26-oct 22:07–22:13 | Pruebas de puertos desde nodob y Windows; auditoría remota | 445 OK / 22 timeout en nodob | — |
| 26-oct 22:15–22:26 | Exportación de evidencias, zip y `scp` a Windows | evidencias_reto1.zip | Permisos 600 |
