#!/usr/bin/env bash
# Exporta la configuración real del servidor Samba a la estructura del repositorio.
# Ejecutar en servidor-samba:  sudo bash scripts/exportar_configuracion.sh
# Luego copiar la carpeta al equipo con git (scp -r) y hacer commit.
set -euo pipefail

DESTINO="${1:-$HOME/samba-seguro-reto1}"
OWNER="${SUDO_USER:-$USER}"

mkdir -p "$DESTINO"/{config/{samba,ssh,ufw,fstab,tailscale},permisos,cuotas,evidencias}

# --- Samba ---
testparm -s 2>/dev/null > "$DESTINO/config/samba/smb.conf"
smbd --version > "$DESTINO/config/samba/version.txt"

# --- SSH ---
cp /etc/ssh/sshd_config.d/01-samba-hardening.conf "$DESTINO/config/ssh/"
sshd -T | grep -Ei '^(port|permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication) ' \
  > "$DESTINO/config/ssh/sshd_efectivo.txt"

# --- Firewall ---
ufw status verbose  > "$DESTINO/config/ufw/ufw_status.txt"
ufw status numbered > "$DESTINO/config/ufw/ufw_numbered.txt"

# --- Almacenamiento y cuotas ---
grep -E 'SAMBA_DATOS|/srv/samba' /etc/fstab > "$DESTINO/config/fstab/fstab_samba.txt"
findmnt /srv/samba > "$DESTINO/config/fstab/findmnt.txt"
repquota -uv /srv/samba 2>/dev/null > "$DESTINO/cuotas/repquota.txt"

# --- Permisos ---
for d in contabilidad rrhh gerencia; do
  getfacl -p "/srv/samba/$d" > "$DESTINO/permisos/acl_$d.txt"
done
ls -ld /srv/samba/* > "$DESTINO/permisos/ls_ld.txt"
for u in laura dana carla; do id "$u"; done > "$DESTINO/permisos/usuarios_id.txt"
pdbedit -L > "$DESTINO/permisos/cuentas_samba.txt"          # solo nombres, sin hashes
[ -f "/home/$OWNER/acl_rrhh_antes.txt" ] && cp "/home/$OWNER/acl_rrhh_antes.txt" "$DESTINO/permisos/"

# --- Red y servicios ---
tailscale serve status > "$DESTINO/config/tailscale/serve_status.txt" 2>&1 || true
ss -tlnp > "$DESTINO/evidencias/puertos_escucha.txt"
systemctl is-active smbd tailscaled ssh.socket > "$DESTINO/evidencias/servicios_activos.txt" || true
systemctl is-enabled nfs-server rpcbind pcsd > "$DESTINO/evidencias/servicios_deshabilitados.txt" 2>&1 || true

# --- Actualizaciones ---
apt list --upgradable 2>/dev/null > "$DESTINO/evidencias/apt_upgradable.txt"

# --- Auditoría (extracto) ---
journalctl -t smbd_audit --no-pager -n 300 > "$DESTINO/evidencias/auditoria_extracto.txt"

# --- Identidad del servidor ---
{ hostnamectl; echo; date; echo; lsb_release -a 2>/dev/null; } > "$DESTINO/evidencias/identidad_servidor.txt"

chown -R "$OWNER": "$DESTINO"
echo "Exportado en $DESTINO"
