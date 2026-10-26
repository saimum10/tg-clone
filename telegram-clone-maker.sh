#!/bin/bash
# Telegram Clone Maker - tar.xz দিয়ে ইনস্টল করা Telegram Desktop এর জন্য
# ডাবল ক্লিক করলে নাম ও লোকেশন জিজ্ঞেস করবে, তারপর ক্লোন + ডেস্কটপ শর্টকাট বানাবে।

TITLE="Telegram Clone Maker"
CONF="$HOME/.config/telegram-clone-maker.conf"
have() { command -v "$1" >/dev/null 2>&1; }

# ডায়ালগ টুল (GNOME এ zenity, KDE তে kdialog) - কোনোটাই না থাকলে zenity ইনস্টল করবে
if ! have zenity && ! have kdialog; then
  pkexec sh -c 'apt-get update; apt-get install -y zenity'
fi
if have zenity; then UI=zenity
elif have kdialog; then UI=kdialog
else echo "zenity বা kdialog ইনস্টল করুন: sudo apt install zenity"; exit 1; fi

ask() {  # $1 = প্রশ্ন, $2 = ডিফল্ট মান
  if [ "$UI" = zenity ]; then
    zenity --entry --title="$TITLE" --width=500 --text="$1" --entry-text="$2"
  else
    kdialog --title "$TITLE" --inputbox "$1" "$2"
  fi
}
yesno() {
  if [ "$UI" = zenity ]; then zenity --question --title="$TITLE" --width=420 --text="$1"
  else kdialog --title "$TITLE" --yesno "$1"; fi
}
info() {
  if [ "$UI" = zenity ]; then zenity --info --title="$TITLE" --width=450 --text="$1"
  else kdialog --title "$TITLE" --msgbox "$1"; fi
}
fail() {
  if [ "$UI" = zenity ]; then zenity --error --title="$TITLE" --width=450 --text="$1"
  else kdialog --title "$TITLE" --error "$1"; fi
  exit 1
}
pick_file() {
  if [ "$UI" = zenity ]; then
    zenity --file-selection --title="Telegram ফোল্ডারের ভেতরের 'Telegram' ফাইলটা বেছে নিন" --filename="$HOME/"
  else
    kdialog --title "Telegram ফোল্ডারের ভেতরের 'Telegram' ফাইলটা বেছে নিন" --getopenfilename "$HOME"
  fi
}

# ১) Telegram (tar.xz) এর চালানোর ফাইল খোঁজা
find_tg() {
  local c f
  if [ -f "$CONF" ]; then
    c=$(sed -n 's/^TG=//p' "$CONF" | head -1)
    [ -f "$c" ] && [ -x "$c" ] && { echo "$c"; return 0; }
  fi
  for c in "$(command -v telegram-desktop)" "$(command -v Telegram)" \
           "$HOME/Telegram/Telegram" "$HOME/.local/share/Telegram/Telegram" \
           "$HOME/Downloads/Telegram/Telegram" "$HOME/ডাউনলোড/Telegram/Telegram" \
           "/opt/Telegram/Telegram" "/opt/telegram/Telegram"; do
    [ -n "$c" ] && [ -f "$c" ] && [ -x "$c" ] && { echo "$c"; return 0; }
  done
  # Telegram এর নিজের তৈরি .desktop ফাইল থেকে path বের করা
  for f in "$HOME"/.local/share/applications/*elegram*.desktop /usr/share/applications/*elegram*.desktop; do
    [ -f "$f" ] || continue
    case "$f" in */telegram-clone-*) continue;; esac
    c=$(sed -n 's/^Exec=//p' "$f" | head -1 | sed 's/^"\([^"]*\)".*/\1/;t;s/ .*//')
    [ -f "$c" ] && [ -x "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}

TG=$(find_tg)
if [ -z "$TG" ]; then
  info "আপনার Telegram (tar.xz) এর 'Telegram' ফাইলটা নিজে খুঁজে পাইনি।
পরের ধাপে Telegram ফোল্ডারের ভেতরের 'Telegram' নামের ফাইলটা বেছে দিন। একবারই জিজ্ঞেস করবে।"
  TG=$(pick_file) || exit 0
  { [ -f "$TG" ] && [ -x "$TG" ]; } || fail "এই ফাইল চালানো যাচ্ছে না: $TG
সঠিক 'Telegram' ফাইলটা বাছুন, বা ফাইলে রাইট-ক্লিক করে Allow executing দিন।"
fi
mkdir -p "$(dirname "$CONF")"
echo "TG=$TG" > "$CONF"

# ২) নাম ও লোকেশন
NAME=$(ask "অ্যাপের নাম দিন (যেমন: Telegram Work):" "Telegram 2") || exit 0
NAME=$(echo "$NAME" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
[ -z "$NAME" ] && fail "নাম দিতে হবে।"
SLUG=$(echo "$NAME" | tr ' ' '_' | tr -d '/\\"'"'"'$`&<>|;')

WORKDIR=$(ask "ডেটা ফোল্ডারের লোকেশন (এই ক্লোনের লগইন ও ডেটা এখানে থাকবে):" \
  "$HOME/.local/share/TelegramClones/$SLUG") || exit 0
WORKDIR="${WORKDIR/#\~/$HOME}"
[ -z "$WORKDIR" ] && fail "লোকেশন দিতে হবে।"

APPS="$HOME/.local/share/applications"
DESK=$(xdg-user-dir DESKTOP 2>/dev/null); [ -z "$DESK" ] && DESK="$HOME/Desktop"
FILE="$APPS/telegram-clone-$SLUG.desktop"

if [ -f "$FILE" ]; then
  yesno "\"$NAME\" নামে ক্লোন আগে থেকেই আছে। শর্টকাট নতুন করে বানাবো? (ডেটা মুছবে না)" || exit 0
fi

mkdir -p "$APPS" "$DESK" "$WORKDIR" || fail "ফোল্ডার বানানো যায়নি: $WORKDIR"

# ৩) Telegram এর আইকন খোঁজা
ICON=""
for f in "$HOME"/.local/share/applications/*elegram*.desktop /usr/share/applications/*elegram*.desktop; do
  case "$f" in */telegram-clone-*) continue;; esac
  [ -f "$f" ] && ICON=$(sed -n 's/^Icon=//p' "$f" | head -1) && [ -n "$ICON" ] && break
done
[ -z "$ICON" ] && ICON=$(find "$HOME/.local/share/icons" /usr/share/icons /usr/share/pixmaps \
  -iname '*telegram*' \( -name '*.png' -o -name '*.svg' \) 2>/dev/null | sort | tail -1)
[ -z "$ICON" ] && ICON="telegram"

# ৪) শর্টকাট ফাইল বানানো
cat > "$FILE" <<EOF
[Desktop Entry]
Type=Application
Name=$NAME
Comment=Telegram clone ($NAME)
Exec="$TG" -many -workdir "$WORKDIR" -- %u
Icon=$ICON
Terminal=false
Categories=Network;InstantMessaging;
EOF
chmod +x "$FILE"
cp -f "$FILE" "$DESK/$NAME.desktop"
chmod +x "$DESK/$NAME.desktop"
# GNOME এ ডেস্কটপ আইকনকে "trusted" করা, নইলে ডাবল ক্লিকে চলে না
gio set "$DESK/$NAME.desktop" metadata::trusted true 2>/dev/null
update-desktop-database "$APPS" 2>/dev/null

# ৫) এই টুলের নিজের শর্টকাট (প্রথমবার চালালে একবারই বানাবে)
SELF=$(readlink -f "$0")
MK="$APPS/telegram-clone-maker.desktop"
if [ ! -f "$MK" ]; then
  cat > "$MK" <<EOF
[Desktop Entry]
Type=Application
Name=Telegram Clone Maker
Exec=bash "$SELF"
Icon=$ICON
Terminal=false
Categories=Network;
EOF
  chmod +x "$MK"
  cp -f "$MK" "$DESK/Telegram Clone Maker.desktop"
  chmod +x "$DESK/Telegram Clone Maker.desktop"
  gio set "$DESK/Telegram Clone Maker.desktop" metadata::trusted true 2>/dev/null
fi

# ৬) চালু করা
setsid nohup "$TG" -many -workdir "$WORKDIR" >/dev/null 2>&1 &

info "তৈরি হয়ে গেছে: $NAME

ডেটা ফোল্ডার: $WORKDIR
শর্টকাট: $DESK

নতুন Telegram উইন্ডোতে এখন লগইন করুন।"
