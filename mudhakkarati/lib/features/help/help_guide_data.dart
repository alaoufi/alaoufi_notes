import 'package:flutter/material.dart';

// مولّد آليًّا: محتوى دليل الاستخدام (البنية + 13 لغة).
class HgItem {
  final IconData icon; final String title; final String desc;
  const HgItem(this.icon, this.title, this.desc);
}
class HgSection {
  final IconData icon; final Color color; final bool expanded;
  final String title; final List<HgItem> items;
  const HgSection(this.icon, this.color, this.expanded, this.title, this.items);
}
class HgChrome { final String subtitle; final String items; final String updated;
  const HgChrome(this.subtitle, this.items, this.updated); }

const _c1 = Color(0xFF5C6BC0);
const _c2 = Color(0xFF26A69A);
const _c3 = Color(0xFFEF6C00);
const _c4 = Color(0xFF42A5F5);
const _c6 = Color(0xFFE53935);
const _c8 = Color(0xFF6D4C41);

const Map<String, List<HgSection>> _hg = {
  'en': [
    HgSection(Icons.add_circle, _c1, true, 'Create a note (+)', [
      HgItem(Icons.edit_note, 'Note', 'Plain text, direction per line'),
      HgItem(Icons.checklist, 'Checklist', 'Lines with checkboxes'),
      HgItem(Icons.mic, 'Voice note', 'Record audio'),
      HgItem(Icons.image, 'Image', 'Attach a photo'),
    ]),
    HgSection(Icons.text_format, _c2, false, 'Formatting', [
      HgItem(Icons.format_bold, 'Bold · Italic · Underline', 'On the selected text'),
      HgItem(Icons.format_color_text, 'Colors', 'Text and highlight color'),
      HgItem(Icons.title, 'Headings & lists', 'Titles, bullets, numbers'),
      HgItem(Icons.format_align_right, 'Alignment', 'Right / center / left'),
      HgItem(Icons.format_line_spacing, 'Line spacing', 'Selected lines (1.0–2.0)'),
      HgItem(Icons.mic_none, 'Voice typing', 'Speak and it writes'),
      HgItem(Icons.picture_as_pdf, 'Export PDF', 'Save the note as PDF'),
      HgItem(Icons.description, 'Export Word', 'Save a .doc file'),
    ]),
    HgSection(Icons.tune, _c3, false, 'Editor tools', [
      HgItem(Icons.push_pin, 'Pin', 'Pin the note to top'),
      HgItem(Icons.palette_outlined, 'Color & page', 'Background, style, ruling'),
      HgItem(Icons.star, 'Favorite', 'Mark as favorite'),
      HgItem(Icons.alarm, 'Reminder', 'One-time or repeating'),
      HgItem(Icons.label_outline, 'Tags', 'Add tags to the note'),
    ]),
    HgSection(Icons.home_outlined, _c4, false, 'Home & navigation', [
      HgItem(Icons.search, 'Search', 'Find in your notes'),
      HgItem(Icons.tune, 'Advanced search', 'Filter by type/date'),
      HgItem(Icons.calendar_month, 'Calendar', 'Notes by date'),
      HgItem(Icons.label, 'Categories', 'Filter by category'),
    ]),
    HgSection(Icons.shield_outlined, _c6, false, 'Security & sync', [
      HgItem(Icons.lock, 'Lock note', 'Protect with a PIN'),
      HgItem(Icons.visibility_off, 'Privacy mode', 'Hide card contents'),
      HgItem(Icons.backup_outlined, 'Backup', 'Save and restore'),
      HgItem(Icons.cloud, 'Google Drive / WebDAV', 'Encrypted cloud sync'),
    ]),
    HgSection(Icons.handyman_outlined, _c8, false, 'More', [
      HgItem(Icons.format_textdirection_r_to_l, 'Per-line direction', 'Arabic right, English left'),
      HgItem(Icons.archive_outlined, 'Archive & Trash', 'Restore your notes'),
      HgItem(Icons.settings_outlined, 'Settings', 'Default page & language'),
    ]),
  ],
  'ar': [
    HgSection(Icons.add_circle, _c1, true, 'إنشاء ملاحظة (+)', [
      HgItem(Icons.edit_note, 'ملاحظة', 'نص عادي، اتجاه لكل سطر'),
      HgItem(Icons.checklist, 'قائمة مهام', 'أسطر بمربعات اختيار'),
      HgItem(Icons.mic, 'ملاحظة صوتية', 'تسجيل صوت'),
      HgItem(Icons.image, 'صورة', 'إرفاق صورة'),
    ]),
    HgSection(Icons.text_format, _c2, false, 'التنسيق', [
      HgItem(Icons.format_bold, 'غامق · مائل · تسطير', 'على النص المحدَّد'),
      HgItem(Icons.format_color_text, 'الألوان', 'لون النص والخلفية'),
      HgItem(Icons.title, 'العناوين والقوائم', 'عناوين، نقاط، أرقام'),
      HgItem(Icons.format_align_right, 'المحاذاة', 'يمين / وسط / يسار'),
      HgItem(Icons.format_line_spacing, 'تباعد الأسطر', 'للأسطر المحدَّدة (1.0–2.0)'),
      HgItem(Icons.mic_none, 'إملاء صوتي', 'تحدّث فيُكتب'),
      HgItem(Icons.picture_as_pdf, 'تصدير PDF', 'حفظ الملاحظة PDF'),
      HgItem(Icons.description, 'تصدير Word', 'حفظ ملف .doc'),
    ]),
    HgSection(Icons.tune, _c3, false, 'أدوات المحرّر', [
      HgItem(Icons.push_pin, 'تثبيت', 'تثبيت الملاحظة أعلى'),
      HgItem(Icons.palette_outlined, 'اللون والصفحة', 'خلفية، نمط، تسطير'),
      HgItem(Icons.star, 'مفضّلة', 'تمييز كمفضّلة'),
      HgItem(Icons.alarm, 'تذكير', 'مرّة أو متكرّر'),
      HgItem(Icons.label_outline, 'وسوم', 'إضافة وسوم'),
    ]),
    HgSection(Icons.home_outlined, _c4, false, 'الرئيسية والتنقّل', [
      HgItem(Icons.search, 'بحث', 'ابحث في ملاحظاتك'),
      HgItem(Icons.tune, 'بحث متقدّم', 'تصفية بالنوع/التاريخ'),
      HgItem(Icons.calendar_month, 'التقويم', 'ملاحظات حسب التاريخ'),
      HgItem(Icons.label, 'التصنيفات', 'تصفية حسب التصنيف'),
    ]),
    HgSection(Icons.shield_outlined, _c6, false, 'الأمان والمزامنة', [
      HgItem(Icons.lock, 'قفل الملاحظة', 'حماية برقم سرّي'),
      HgItem(Icons.visibility_off, 'وضع الخصوصية', 'إخفاء محتوى البطاقات'),
      HgItem(Icons.backup_outlined, 'نسخ احتياطي', 'حفظ واستعادة'),
      HgItem(Icons.cloud, 'Google Drive / WebDAV', 'مزامنة سحابية مشفّرة'),
    ]),
    HgSection(Icons.handyman_outlined, _c8, false, 'المزيد', [
      HgItem(Icons.format_textdirection_r_to_l, 'اتجاه لكل سطر', 'العربي يمين والإنجليزي يسار'),
      HgItem(Icons.archive_outlined, 'الأرشيف والمهملات', 'استرجاع ملاحظاتك'),
      HgItem(Icons.settings_outlined, 'الإعدادات', 'الصفحة الافتراضية واللغة'),
    ]),
  ],
  'es': [
    HgSection(Icons.add_circle, _c1, true, 'Crear una nota (+)', [
      HgItem(Icons.edit_note, 'Nota', 'Texto simple, dirección por línea'),
      HgItem(Icons.checklist, 'Lista de tareas', 'Líneas con casillas'),
      HgItem(Icons.mic, 'Nota de voz', 'Grabar audio'),
      HgItem(Icons.image, 'Imagen', 'Adjuntar una foto'),
    ]),
    HgSection(Icons.text_format, _c2, false, 'Formato', [
      HgItem(Icons.format_bold, 'Negrita · Cursiva · Subrayado', 'En el texto seleccionado'),
      HgItem(Icons.format_color_text, 'Colores', 'Color de texto y fondo'),
      HgItem(Icons.title, 'Títulos y listas', 'Títulos, viñetas, números'),
      HgItem(Icons.format_align_right, 'Alineación', 'Derecha / centro / izquierda'),
      HgItem(Icons.format_line_spacing, 'Interlineado', 'Líneas seleccionadas (1.0–2.0)'),
      HgItem(Icons.mic_none, 'Dictado por voz', 'Habla y se escribe'),
      HgItem(Icons.picture_as_pdf, 'Exportar PDF', 'Guardar la nota como PDF'),
      HgItem(Icons.description, 'Exportar Word', 'Guardar un archivo .doc'),
    ]),
    HgSection(Icons.tune, _c3, false, 'Herramientas del editor', [
      HgItem(Icons.push_pin, 'Fijar', 'Fijar la nota arriba'),
      HgItem(Icons.palette_outlined, 'Color y página', 'Fondo, estilo, líneas'),
      HgItem(Icons.star, 'Favorito', 'Marcar como favorito'),
      HgItem(Icons.alarm, 'Recordatorio', 'Único o repetido'),
      HgItem(Icons.label_outline, 'Etiquetas', 'Añadir etiquetas'),
    ]),
    HgSection(Icons.home_outlined, _c4, false, 'Inicio y navegación', [
      HgItem(Icons.search, 'Buscar', 'Buscar en tus notas'),
      HgItem(Icons.tune, 'Búsqueda avanzada', 'Filtrar por tipo/fecha'),
      HgItem(Icons.calendar_month, 'Calendario', 'Notas por fecha'),
      HgItem(Icons.label, 'Categorías', 'Filtrar por categoría'),
    ]),
    HgSection(Icons.shield_outlined, _c6, false, 'Seguridad y sincronización', [
      HgItem(Icons.lock, 'Bloquear nota', 'Proteger con PIN'),
      HgItem(Icons.visibility_off, 'Modo privado', 'Ocultar contenido'),
      HgItem(Icons.backup_outlined, 'Copia de seguridad', 'Guardar y restaurar'),
      HgItem(Icons.cloud, 'Google Drive / WebDAV', 'Sincronización cifrada'),
    ]),
    HgSection(Icons.handyman_outlined, _c8, false, 'Más', [
      HgItem(Icons.format_textdirection_r_to_l, 'Dirección por línea', 'Árabe a la derecha, inglés a la izquierda'),
      HgItem(Icons.archive_outlined, 'Archivo y papelera', 'Restaurar tus notas'),
      HgItem(Icons.settings_outlined, 'Ajustes', 'Página e idioma por defecto'),
    ]),
  ],
  'de': [
    HgSection(Icons.add_circle, _c1, true, 'Notiz erstellen (+)', [
      HgItem(Icons.edit_note, 'Notiz', 'Einfacher Text, Richtung pro Zeile'),
      HgItem(Icons.checklist, 'Checkliste', 'Zeilen mit Kästchen'),
      HgItem(Icons.mic, 'Sprachnotiz', 'Audio aufnehmen'),
      HgItem(Icons.image, 'Bild', 'Foto anhängen'),
    ]),
    HgSection(Icons.text_format, _c2, false, 'Formatierung', [
      HgItem(Icons.format_bold, 'Fett · Kursiv · Unterstrichen', 'Auf dem markierten Text'),
      HgItem(Icons.format_color_text, 'Farben', 'Text- und Hintergrundfarbe'),
      HgItem(Icons.title, 'Überschriften & Listen', 'Titel, Aufzählung, Nummern'),
      HgItem(Icons.format_align_right, 'Ausrichtung', 'Rechts / Mitte / links'),
      HgItem(Icons.format_line_spacing, 'Zeilenabstand', 'Markierte Zeilen (1.0–2.0)'),
      HgItem(Icons.mic_none, 'Spracheingabe', 'Sprich, es schreibt'),
      HgItem(Icons.picture_as_pdf, 'PDF exportieren', 'Notiz als PDF speichern'),
      HgItem(Icons.description, 'Word exportieren', '.doc-Datei speichern'),
    ]),
    HgSection(Icons.tune, _c3, false, 'Editor-Werkzeuge', [
      HgItem(Icons.push_pin, 'Anheften', 'Notiz oben anheften'),
      HgItem(Icons.palette_outlined, 'Farbe & Seite', 'Hintergrund, Stil, Linien'),
      HgItem(Icons.star, 'Favorit', 'Als Favorit markieren'),
      HgItem(Icons.alarm, 'Erinnerung', 'Einmalig oder wiederholt'),
      HgItem(Icons.label_outline, 'Tags', 'Tags hinzufügen'),
    ]),
    HgSection(Icons.home_outlined, _c4, false, 'Start & Navigation', [
      HgItem(Icons.search, 'Suche', 'In Notizen suchen'),
      HgItem(Icons.tune, 'Erweiterte Suche', 'Nach Typ/Datum filtern'),
      HgItem(Icons.calendar_month, 'Kalender', 'Notizen nach Datum'),
      HgItem(Icons.label, 'Kategorien', 'Nach Kategorie filtern'),
    ]),
    HgSection(Icons.shield_outlined, _c6, false, 'Sicherheit & Sync', [
      HgItem(Icons.lock, 'Notiz sperren', 'Mit PIN schützen'),
      HgItem(Icons.visibility_off, 'Privatmodus', 'Inhalte verbergen'),
      HgItem(Icons.backup_outlined, 'Sicherung', 'Speichern & wiederherstellen'),
      HgItem(Icons.cloud, 'Google Drive / WebDAV', 'Verschlüsselte Sync'),
    ]),
    HgSection(Icons.handyman_outlined, _c8, false, 'Mehr', [
      HgItem(Icons.format_textdirection_r_to_l, 'Richtung pro Zeile', 'Arabisch rechts, Englisch links'),
      HgItem(Icons.archive_outlined, 'Archiv & Papierkorb', 'Notizen wiederherstellen'),
      HgItem(Icons.settings_outlined, 'Einstellungen', 'Standardseite & Sprache'),
    ]),
  ],
  'fil': [
    HgSection(Icons.add_circle, _c1, true, 'Gumawa ng tala (+)', [
      HgItem(Icons.edit_note, 'Tala', 'Plain text, direksyon kada linya'),
      HgItem(Icons.checklist, 'Checklist', 'Mga linyang may checkbox'),
      HgItem(Icons.mic, 'Talang boses', 'Mag-record ng audio'),
      HgItem(Icons.image, 'Larawan', 'Maglakip ng larawan'),
    ]),
    HgSection(Icons.text_format, _c2, false, 'Pag-format', [
      HgItem(Icons.format_bold, 'Bold · Italic · Underline', 'Sa napiling teksto'),
      HgItem(Icons.format_color_text, 'Mga kulay', 'Kulay ng teksto at highlight'),
      HgItem(Icons.title, 'Heading at listahan', 'Pamagat, bullet, numero'),
      HgItem(Icons.format_align_right, 'Pagkakahanay', 'Kanan / gitna / kaliwa'),
      HgItem(Icons.format_line_spacing, 'Espasyo ng linya', 'Mga napiling linya (1.0–2.0)'),
      HgItem(Icons.mic_none, 'Pagdidikta sa boses', 'Magsalita, isusulat'),
      HgItem(Icons.picture_as_pdf, 'I-export sa PDF', 'I-save bilang PDF'),
      HgItem(Icons.description, 'I-export sa Word', 'I-save na .doc'),
    ]),
    HgSection(Icons.tune, _c3, false, 'Mga tool sa editor', [
      HgItem(Icons.push_pin, 'I-pin', 'I-pin sa itaas'),
      HgItem(Icons.palette_outlined, 'Kulay at pahina', 'Background, istilo, linya'),
      HgItem(Icons.star, 'Paborito', 'Markahan paborito'),
      HgItem(Icons.alarm, 'Paalala', 'Isahan o paulit-ulit'),
      HgItem(Icons.label_outline, 'Mga tag', 'Magdagdag ng tag'),
    ]),
    HgSection(Icons.home_outlined, _c4, false, 'Home at nabigasyon', [
      HgItem(Icons.search, 'Hanapin', 'Maghanap sa tala'),
      HgItem(Icons.tune, 'Advanced na paghahanap', 'Filter ayon sa uri/petsa'),
      HgItem(Icons.calendar_month, 'Kalendaryo', 'Tala ayon sa petsa'),
      HgItem(Icons.label, 'Kategorya', 'Filter ayon sa kategorya'),
    ]),
    HgSection(Icons.shield_outlined, _c6, false, 'Seguridad at sync', [
      HgItem(Icons.lock, 'I-lock ang tala', 'Protektahan ng PIN'),
      HgItem(Icons.visibility_off, 'Privacy mode', 'Itago ang nilalaman'),
      HgItem(Icons.backup_outlined, 'Backup', 'I-save at ibalik'),
      HgItem(Icons.cloud, 'Google Drive / WebDAV', 'Naka-encrypt na sync'),
    ]),
    HgSection(Icons.handyman_outlined, _c8, false, 'Iba pa', [
      HgItem(Icons.format_textdirection_r_to_l, 'Direksyon kada linya', 'Arabe kanan, Ingles kaliwa'),
      HgItem(Icons.archive_outlined, 'Archive at basurahan', 'Ibalik ang tala'),
      HgItem(Icons.settings_outlined, 'Mga Setting', 'Default na pahina at wika'),
    ]),
  ],
  'fr': [
    HgSection(Icons.add_circle, _c1, true, 'Créer une note (+)', [
      HgItem(Icons.edit_note, 'Note', 'Texte simple, direction par ligne'),
      HgItem(Icons.checklist, 'Liste de tâches', 'Lignes avec cases'),
      HgItem(Icons.mic, 'Note vocale', 'Enregistrer l’audio'),
      HgItem(Icons.image, 'Image', 'Joindre une photo'),
    ]),
    HgSection(Icons.text_format, _c2, false, 'Mise en forme', [
      HgItem(Icons.format_bold, 'Gras · Italique · Souligné', 'Sur le texte sélectionné'),
      HgItem(Icons.format_color_text, 'Couleurs', 'Couleur du texte et du fond'),
      HgItem(Icons.title, 'Titres et listes', 'Titres, puces, numéros'),
      HgItem(Icons.format_align_right, 'Alignement', 'Droite / centre / gauche'),
      HgItem(Icons.format_line_spacing, 'Interligne', 'Lignes sélectionnées (1.0–2.0)'),
      HgItem(Icons.mic_none, 'Dictée vocale', 'Parlez, ça s’écrit'),
      HgItem(Icons.picture_as_pdf, 'Exporter en PDF', 'Enregistrer en PDF'),
      HgItem(Icons.description, 'Exporter en Word', 'Enregistrer un .doc'),
    ]),
    HgSection(Icons.tune, _c3, false, 'Outils de l’éditeur', [
      HgItem(Icons.push_pin, 'Épingler', 'Épingler en haut'),
      HgItem(Icons.palette_outlined, 'Couleur et page', 'Fond, style, lignes'),
      HgItem(Icons.star, 'Favori', 'Marquer comme favori'),
      HgItem(Icons.alarm, 'Rappel', 'Unique ou répété'),
      HgItem(Icons.label_outline, 'Étiquettes', 'Ajouter des étiquettes'),
    ]),
    HgSection(Icons.home_outlined, _c4, false, 'Accueil et navigation', [
      HgItem(Icons.search, 'Rechercher', 'Chercher dans vos notes'),
      HgItem(Icons.tune, 'Recherche avancée', 'Filtrer par type/date'),
      HgItem(Icons.calendar_month, 'Calendrier', 'Notes par date'),
      HgItem(Icons.label, 'Catégories', 'Filtrer par catégorie'),
    ]),
    HgSection(Icons.shield_outlined, _c6, false, 'Sécurité et sync', [
      HgItem(Icons.lock, 'Verrouiller la note', 'Protéger par PIN'),
      HgItem(Icons.visibility_off, 'Mode privé', 'Masquer le contenu'),
      HgItem(Icons.backup_outlined, 'Sauvegarde', 'Enregistrer et restaurer'),
      HgItem(Icons.cloud, 'Google Drive / WebDAV', 'Sync chiffrée'),
    ]),
    HgSection(Icons.handyman_outlined, _c8, false, 'Plus', [
      HgItem(Icons.format_textdirection_r_to_l, 'Direction par ligne', 'Arabe à droite, anglais à gauche'),
      HgItem(Icons.archive_outlined, 'Archives et corbeille', 'Restaurer vos notes'),
      HgItem(Icons.settings_outlined, 'Paramètres', 'Page et langue par défaut'),
    ]),
  ],
  'id': [
    HgSection(Icons.add_circle, _c1, true, 'Buat catatan (+)', [
      HgItem(Icons.edit_note, 'Catatan', 'Teks biasa, arah per baris'),
      HgItem(Icons.checklist, 'Daftar tugas', 'Baris dengan kotak centang'),
      HgItem(Icons.mic, 'Catatan suara', 'Rekam audio'),
      HgItem(Icons.image, 'Gambar', 'Lampirkan foto'),
    ]),
    HgSection(Icons.text_format, _c2, false, 'Pemformatan', [
      HgItem(Icons.format_bold, 'Tebal · Miring · Garis bawah', 'Pada teks terpilih'),
      HgItem(Icons.format_color_text, 'Warna', 'Warna teks dan sorotan'),
      HgItem(Icons.title, 'Judul & daftar', 'Judul, poin, angka'),
      HgItem(Icons.format_align_right, 'Perataan', 'Kanan / tengah / kiri'),
      HgItem(Icons.format_line_spacing, 'Spasi baris', 'Baris terpilih (1.0–2.0)'),
      HgItem(Icons.mic_none, 'Pengetikan suara', 'Bicara, ditulis'),
      HgItem(Icons.picture_as_pdf, 'Ekspor PDF', 'Simpan sebagai PDF'),
      HgItem(Icons.description, 'Ekspor Word', 'Simpan berkas .doc'),
    ]),
    HgSection(Icons.tune, _c3, false, 'Alat editor', [
      HgItem(Icons.push_pin, 'Sematkan', 'Sematkan ke atas'),
      HgItem(Icons.palette_outlined, 'Warna & halaman', 'Latar, gaya, garis'),
      HgItem(Icons.star, 'Favorit', 'Tandai favorit'),
      HgItem(Icons.alarm, 'Pengingat', 'Sekali atau berulang'),
      HgItem(Icons.label_outline, 'Tag', 'Tambah tag'),
    ]),
    HgSection(Icons.home_outlined, _c4, false, 'Beranda & navigasi', [
      HgItem(Icons.search, 'Cari', 'Cari di catatan'),
      HgItem(Icons.tune, 'Pencarian lanjutan', 'Filter jenis/tanggal'),
      HgItem(Icons.calendar_month, 'Kalender', 'Catatan per tanggal'),
      HgItem(Icons.label, 'Kategori', 'Filter per kategori'),
    ]),
    HgSection(Icons.shield_outlined, _c6, false, 'Keamanan & sinkron', [
      HgItem(Icons.lock, 'Kunci catatan', 'Lindungi dengan PIN'),
      HgItem(Icons.visibility_off, 'Mode privasi', 'Sembunyikan isi'),
      HgItem(Icons.backup_outlined, 'Cadangan', 'Simpan dan pulihkan'),
      HgItem(Icons.cloud, 'Google Drive / WebDAV', 'Sinkron terenkripsi'),
    ]),
    HgSection(Icons.handyman_outlined, _c8, false, 'Lainnya', [
      HgItem(Icons.format_textdirection_r_to_l, 'Arah per baris', 'Arab kanan, Inggris kiri'),
      HgItem(Icons.archive_outlined, 'Arsip & sampah', 'Pulihkan catatan'),
      HgItem(Icons.settings_outlined, 'Pengaturan', 'Halaman & bahasa default'),
    ]),
  ],
  'it': [
    HgSection(Icons.add_circle, _c1, true, 'Crea una nota (+)', [
      HgItem(Icons.edit_note, 'Nota', 'Testo semplice, direzione per riga'),
      HgItem(Icons.checklist, 'Lista attività', 'Righe con caselle'),
      HgItem(Icons.mic, 'Nota vocale', 'Registra audio'),
      HgItem(Icons.image, 'Immagine', 'Allega una foto'),
    ]),
    HgSection(Icons.text_format, _c2, false, 'Formattazione', [
      HgItem(Icons.format_bold, 'Grassetto · Corsivo · Sottolineato', 'Sul testo selezionato'),
      HgItem(Icons.format_color_text, 'Colori', 'Colore testo e sfondo'),
      HgItem(Icons.title, 'Titoli ed elenchi', 'Titoli, punti, numeri'),
      HgItem(Icons.format_align_right, 'Allineamento', 'Destra / centro / sinistra'),
      HgItem(Icons.format_line_spacing, 'Interlinea', 'Righe selezionate (1.0–2.0)'),
      HgItem(Icons.mic_none, 'Dettatura vocale', 'Parla e scrive'),
      HgItem(Icons.picture_as_pdf, 'Esporta PDF', 'Salva la nota in PDF'),
      HgItem(Icons.description, 'Esporta Word', 'Salva un file .doc'),
    ]),
    HgSection(Icons.tune, _c3, false, 'Strumenti editor', [
      HgItem(Icons.push_pin, 'Fissa', 'Fissa in alto'),
      HgItem(Icons.palette_outlined, 'Colore e pagina', 'Sfondo, stile, righe'),
      HgItem(Icons.star, 'Preferito', 'Segna come preferito'),
      HgItem(Icons.alarm, 'Promemoria', 'Singolo o ripetuto'),
      HgItem(Icons.label_outline, 'Tag', 'Aggiungi tag'),
    ]),
    HgSection(Icons.home_outlined, _c4, false, 'Home e navigazione', [
      HgItem(Icons.search, 'Cerca', 'Cerca nelle note'),
      HgItem(Icons.tune, 'Ricerca avanzata', 'Filtra per tipo/data'),
      HgItem(Icons.calendar_month, 'Calendario', 'Note per data'),
      HgItem(Icons.label, 'Categorie', 'Filtra per categoria'),
    ]),
    HgSection(Icons.shield_outlined, _c6, false, 'Sicurezza e sync', [
      HgItem(Icons.lock, 'Blocca nota', 'Proteggi con PIN'),
      HgItem(Icons.visibility_off, 'Modalità privata', 'Nascondi contenuti'),
      HgItem(Icons.backup_outlined, 'Backup', 'Salva e ripristina'),
      HgItem(Icons.cloud, 'Google Drive / WebDAV', 'Sync crittografata'),
    ]),
    HgSection(Icons.handyman_outlined, _c8, false, 'Altro', [
      HgItem(Icons.format_textdirection_r_to_l, 'Direzione per riga', 'Arabo a destra, inglese a sinistra'),
      HgItem(Icons.archive_outlined, 'Archivio e cestino', 'Ripristina le note'),
      HgItem(Icons.settings_outlined, 'Impostazioni', 'Pagina e lingua predefinite'),
    ]),
  ],
  'ms': [
    HgSection(Icons.add_circle, _c1, true, 'Buat nota (+)', [
      HgItem(Icons.edit_note, 'Nota', 'Teks biasa, arah setiap baris'),
      HgItem(Icons.checklist, 'Senarai tugas', 'Baris dengan kotak semak'),
      HgItem(Icons.mic, 'Nota suara', 'Rakam audio'),
      HgItem(Icons.image, 'Imej', 'Lampirkan foto'),
    ]),
    HgSection(Icons.text_format, _c2, false, 'Pemformatan', [
      HgItem(Icons.format_bold, 'Tebal · Condong · Garis bawah', 'Pada teks dipilih'),
      HgItem(Icons.format_color_text, 'Warna', 'Warna teks dan sorotan'),
      HgItem(Icons.title, 'Tajuk & senarai', 'Tajuk, bulet, nombor'),
      HgItem(Icons.format_align_right, 'Penjajaran', 'Kanan / tengah / kiri'),
      HgItem(Icons.format_line_spacing, 'Jarak baris', 'Baris dipilih (1.0–2.0)'),
      HgItem(Icons.mic_none, 'Taip suara', 'Cakap, ia menulis'),
      HgItem(Icons.picture_as_pdf, 'Eksport PDF', 'Simpan sebagai PDF'),
      HgItem(Icons.description, 'Eksport Word', 'Simpan fail .doc'),
    ]),
    HgSection(Icons.tune, _c3, false, 'Alat editor', [
      HgItem(Icons.push_pin, 'Sematkan', 'Sematkan ke atas'),
      HgItem(Icons.palette_outlined, 'Warna & halaman', 'Latar, gaya, garis'),
      HgItem(Icons.star, 'Kegemaran', 'Tanda kegemaran'),
      HgItem(Icons.alarm, 'Peringatan', 'Sekali atau berulang'),
      HgItem(Icons.label_outline, 'Tag', 'Tambah tag'),
    ]),
    HgSection(Icons.home_outlined, _c4, false, 'Utama & navigasi', [
      HgItem(Icons.search, 'Cari', 'Cari dalam nota'),
      HgItem(Icons.tune, 'Carian lanjutan', 'Tapis jenis/tarikh'),
      HgItem(Icons.calendar_month, 'Kalendar', 'Nota mengikut tarikh'),
      HgItem(Icons.label, 'Kategori', 'Tapis mengikut kategori'),
    ]),
    HgSection(Icons.shield_outlined, _c6, false, 'Keselamatan & segerak', [
      HgItem(Icons.lock, 'Kunci nota', 'Lindungi dengan PIN'),
      HgItem(Icons.visibility_off, 'Mod privasi', 'Sembunyi kandungan'),
      HgItem(Icons.backup_outlined, 'Sandaran', 'Simpan dan pulih'),
      HgItem(Icons.cloud, 'Google Drive / WebDAV', 'Segerak tersulit'),
    ]),
    HgSection(Icons.handyman_outlined, _c8, false, 'Lagi', [
      HgItem(Icons.format_textdirection_r_to_l, 'Arah setiap baris', 'Arab kanan, Inggeris kiri'),
      HgItem(Icons.archive_outlined, 'Arkib & sampah', 'Pulihkan nota anda'),
      HgItem(Icons.settings_outlined, 'Tetapan', 'Halaman & bahasa lalai'),
    ]),
  ],
  'hi': [
    HgSection(Icons.add_circle, _c1, true, 'नोट बनाएँ (+)', [
      HgItem(Icons.edit_note, 'नोट', 'सादा टेक्स्ट, हर लाइन की दिशा'),
      HgItem(Icons.checklist, 'चेकलिस्ट', 'चेकबॉक्स वाली लाइनें'),
      HgItem(Icons.mic, 'वॉइस नोट', 'ऑडियो रिकॉर्ड करें'),
      HgItem(Icons.image, 'इमेज', 'फ़ोटो जोड़ें'),
    ]),
    HgSection(Icons.text_format, _c2, false, 'फ़ॉर्मेटिंग', [
      HgItem(Icons.format_bold, 'बोल्ड · इटैलिक · रेखांकित', 'चयनित टेक्स्ट पर'),
      HgItem(Icons.format_color_text, 'रंग', 'टेक्स्ट और हाइलाइट रंग'),
      HgItem(Icons.title, 'शीर्षक और सूचियाँ', 'शीर्षक, बुलेट, नंबर'),
      HgItem(Icons.format_align_right, 'संरेखण', 'दाएँ / केंद्र / बाएँ'),
      HgItem(Icons.format_line_spacing, 'लाइन स्पेसिंग', 'चयनित लाइनें (1.0–2.0)'),
      HgItem(Icons.mic_none, 'वॉइस टाइपिंग', 'बोलें, यह लिखता है'),
      HgItem(Icons.picture_as_pdf, 'PDF निर्यात', 'नोट को PDF सहेजें'),
      HgItem(Icons.description, 'Word निर्यात', '.doc फ़ाइल सहेजें'),
    ]),
    HgSection(Icons.tune, _c3, false, 'एडिटर टूल', [
      HgItem(Icons.push_pin, 'पिन', 'ऊपर पिन करें'),
      HgItem(Icons.palette_outlined, 'रंग और पेज', 'पृष्ठभूमि, शैली, रेखाएँ'),
      HgItem(Icons.star, 'पसंदीदा', 'पसंदीदा चिह्नित करें'),
      HgItem(Icons.alarm, 'रिमाइंडर', 'एक बार या दोहराव'),
      HgItem(Icons.label_outline, 'टैग', 'टैग जोड़ें'),
    ]),
    HgSection(Icons.home_outlined, _c4, false, 'होम और नेविगेशन', [
      HgItem(Icons.search, 'खोज', 'अपने नोट्स में खोजें'),
      HgItem(Icons.tune, 'उन्नत खोज', 'प्रकार/तारीख से फ़िल्टर'),
      HgItem(Icons.calendar_month, 'कैलेंडर', 'तारीख अनुसार नोट'),
      HgItem(Icons.label, 'श्रेणियाँ', 'श्रेणी से फ़िल्टर'),
    ]),
    HgSection(Icons.shield_outlined, _c6, false, 'सुरक्षा और सिंक', [
      HgItem(Icons.lock, 'नोट लॉक', 'PIN से सुरक्षा'),
      HgItem(Icons.visibility_off, 'प्राइवेसी मोड', 'सामग्री छिपाएँ'),
      HgItem(Icons.backup_outlined, 'बैकअप', 'सहेजें और पुनर्स्थापित'),
      HgItem(Icons.cloud, 'Google Drive / WebDAV', 'एन्क्रिप्टेड सिंक'),
    ]),
    HgSection(Icons.handyman_outlined, _c8, false, 'अधिक', [
      HgItem(Icons.format_textdirection_r_to_l, 'हर लाइन की दिशा', 'अरबी दाएँ, अंग्रेज़ी बाएँ'),
      HgItem(Icons.archive_outlined, 'आर्काइव और ट्रैश', 'नोट्स पुनर्स्थापित करें'),
      HgItem(Icons.settings_outlined, 'सेटिंग्स', 'डिफ़ॉल्ट पेज और भाषा'),
    ]),
  ],
  'bn': [
    HgSection(Icons.add_circle, _c1, true, 'নোট তৈরি (+)', [
      HgItem(Icons.edit_note, 'নোট', 'সাধারণ টেক্সট, প্রতি লাইনে দিক'),
      HgItem(Icons.checklist, 'চেকলিস্ট', 'চেকবক্স সহ লাইন'),
      HgItem(Icons.mic, 'ভয়েস নোট', 'অডিও রেকর্ড'),
      HgItem(Icons.image, 'ছবি', 'ছবি সংযুক্ত করুন'),
    ]),
    HgSection(Icons.text_format, _c2, false, 'ফরম্যাটিং', [
      HgItem(Icons.format_bold, 'বোল্ড · ইটালিক · আন্ডারলাইন', 'নির্বাচিত টেক্সটে'),
      HgItem(Icons.format_color_text, 'রং', 'টেক্সট ও হাইলাইট রং'),
      HgItem(Icons.title, 'শিরোনাম ও তালিকা', 'শিরোনাম, বুলেট, সংখ্যা'),
      HgItem(Icons.format_align_right, 'প্রান্তিককরণ', 'ডান / মাঝ / বাম'),
      HgItem(Icons.format_line_spacing, 'লাইন স্পেসিং', 'নির্বাচিত লাইন (1.0–2.0)'),
      HgItem(Icons.mic_none, 'ভয়েস টাইপিং', 'বলুন, এটি লেখে'),
      HgItem(Icons.picture_as_pdf, 'PDF এক্সপোর্ট', 'নোট PDF সংরক্ষণ'),
      HgItem(Icons.description, 'Word এক্সপোর্ট', '.doc ফাইল সংরক্ষণ'),
    ]),
    HgSection(Icons.tune, _c3, false, 'এডিটর সরঞ্জাম', [
      HgItem(Icons.push_pin, 'পিন', 'উপরে পিন করুন'),
      HgItem(Icons.palette_outlined, 'রং ও পৃষ্ঠা', 'পটভূমি, স্টাইল, রেখা'),
      HgItem(Icons.star, 'প্রিয়', 'প্রিয় চিহ্নিত করুন'),
      HgItem(Icons.alarm, 'রিমাইন্ডার', 'একবার বা পুনরাবৃত্ত'),
      HgItem(Icons.label_outline, 'ট্যাগ', 'ট্যাগ যোগ করুন'),
    ]),
    HgSection(Icons.home_outlined, _c4, false, 'হোম ও নেভিগেশন', [
      HgItem(Icons.search, 'অনুসন্ধান', 'নোটে খুঁজুন'),
      HgItem(Icons.tune, 'উন্নত অনুসন্ধান', 'ধরন/তারিখে ফিল্টার'),
      HgItem(Icons.calendar_month, 'ক্যালেন্ডার', 'তারিখ অনুযায়ী নোট'),
      HgItem(Icons.label, 'বিভাগ', 'বিভাগ অনুযায়ী ফিল্টার'),
    ]),
    HgSection(Icons.shield_outlined, _c6, false, 'নিরাপত্তা ও সিঙ্ক', [
      HgItem(Icons.lock, 'নোট লক', 'PIN দিয়ে সুরক্ষা'),
      HgItem(Icons.visibility_off, 'প্রাইভেসি মোড', 'বিষয়বস্তু লুকান'),
      HgItem(Icons.backup_outlined, 'ব্যাকআপ', 'সংরক্ষণ ও পুনরুদ্ধার'),
      HgItem(Icons.cloud, 'Google Drive / WebDAV', 'এনক্রিপ্টেড সিঙ্ক'),
    ]),
    HgSection(Icons.handyman_outlined, _c8, false, 'আরও', [
      HgItem(Icons.format_textdirection_r_to_l, 'প্রতি লাইনে দিক', 'আরবি ডানে, ইংরেজি বামে'),
      HgItem(Icons.archive_outlined, 'আর্কাইভ ও ট্র্যাশ', 'নোট পুনরুদ্ধার'),
      HgItem(Icons.settings_outlined, 'সেটিংস', 'ডিফল্ট পৃষ্ঠা ও ভাষা'),
    ]),
  ],
  'fa': [
    HgSection(Icons.add_circle, _c1, true, 'ساخت یادداشت (+)', [
      HgItem(Icons.edit_note, 'یادداشت', 'متن ساده، جهت هر خط'),
      HgItem(Icons.checklist, 'فهرست کارها', 'خطوط با کادر تیک'),
      HgItem(Icons.mic, 'یادداشت صوتی', 'ضبط صدا'),
      HgItem(Icons.image, 'تصویر', 'پیوست عکس'),
    ]),
    HgSection(Icons.text_format, _c2, false, 'قالب‌بندی', [
      HgItem(Icons.format_bold, 'پررنگ · کج · زیرخط', 'روی متن انتخاب‌شده'),
      HgItem(Icons.format_color_text, 'رنگ‌ها', 'رنگ متن و هایلایت'),
      HgItem(Icons.title, 'عنوان‌ها و فهرست‌ها', 'عنوان، گلوله، شماره'),
      HgItem(Icons.format_align_right, 'ترازبندی', 'راست / وسط / چپ'),
      HgItem(Icons.format_line_spacing, 'فاصله خطوط', 'خطوط انتخابی (1.0–2.0)'),
      HgItem(Icons.mic_none, 'تایپ صوتی', 'صحبت کن، می‌نویسد'),
      HgItem(Icons.picture_as_pdf, 'خروجی PDF', 'ذخیره یادداشت به PDF'),
      HgItem(Icons.description, 'خروجی Word', 'ذخیره فایل .doc'),
    ]),
    HgSection(Icons.tune, _c3, false, 'ابزارهای ویرایشگر', [
      HgItem(Icons.push_pin, 'سنجاق', 'سنجاق به بالا'),
      HgItem(Icons.palette_outlined, 'رنگ و صفحه', 'پس‌زمینه، سبک، خطوط'),
      HgItem(Icons.star, 'علاقه‌مندی', 'علامت علاقه‌مندی'),
      HgItem(Icons.alarm, 'یادآور', 'یک‌بار یا تکرارشونده'),
      HgItem(Icons.label_outline, 'برچسب‌ها', 'افزودن برچسب'),
    ]),
    HgSection(Icons.home_outlined, _c4, false, 'خانه و پیمایش', [
      HgItem(Icons.search, 'جستجو', 'جستجو در یادداشت‌ها'),
      HgItem(Icons.tune, 'جستجوی پیشرفته', 'فیلتر بر اساس نوع/تاریخ'),
      HgItem(Icons.calendar_month, 'تقویم', 'یادداشت بر اساس تاریخ'),
      HgItem(Icons.label, 'دسته‌ها', 'فیلتر بر اساس دسته'),
    ]),
    HgSection(Icons.shield_outlined, _c6, false, 'امنیت و همگام‌سازی', [
      HgItem(Icons.lock, 'قفل یادداشت', 'محافظت با PIN'),
      HgItem(Icons.visibility_off, 'حالت حریم خصوصی', 'پنهان کردن محتوا'),
      HgItem(Icons.backup_outlined, 'پشتیبان', 'ذخیره و بازیابی'),
      HgItem(Icons.cloud, 'Google Drive / WebDAV', 'همگام‌سازی رمزنگاری‌شده'),
    ]),
    HgSection(Icons.handyman_outlined, _c8, false, 'بیشتر', [
      HgItem(Icons.format_textdirection_r_to_l, 'جهت هر خط', 'عربی راست، انگلیسی چپ'),
      HgItem(Icons.archive_outlined, 'بایگانی و زباله‌دان', 'بازیابی یادداشت‌ها'),
      HgItem(Icons.settings_outlined, 'تنظیمات', 'صفحه و زبان پیش‌فرض'),
    ]),
  ],
  'ru': [
    HgSection(Icons.add_circle, _c1, true, 'Создать заметку (+)', [
      HgItem(Icons.edit_note, 'Заметка', 'Простой текст, направление по строке'),
      HgItem(Icons.checklist, 'Список задач', 'Строки с флажками'),
      HgItem(Icons.mic, 'Голосовая заметка', 'Запись звука'),
      HgItem(Icons.image, 'Изображение', 'Прикрепить фото'),
    ]),
    HgSection(Icons.text_format, _c2, false, 'Форматирование', [
      HgItem(Icons.format_bold, 'Жирный · Курсив · Подчёркнутый', 'К выделенному тексту'),
      HgItem(Icons.format_color_text, 'Цвета', 'Цвет текста и фона'),
      HgItem(Icons.title, 'Заголовки и списки', 'Заголовки, маркеры, номера'),
      HgItem(Icons.format_align_right, 'Выравнивание', 'Право / центр / лево'),
      HgItem(Icons.format_line_spacing, 'Межстрочный интервал', 'Выбранные строки (1.0–2.0)'),
      HgItem(Icons.mic_none, 'Голосовой ввод', 'Говорите — пишется'),
      HgItem(Icons.picture_as_pdf, 'Экспорт в PDF', 'Сохранить как PDF'),
      HgItem(Icons.description, 'Экспорт в Word', 'Сохранить файл .doc'),
    ]),
    HgSection(Icons.tune, _c3, false, 'Инструменты редактора', [
      HgItem(Icons.push_pin, 'Закрепить', 'Закрепить вверху'),
      HgItem(Icons.palette_outlined, 'Цвет и страница', 'Фон, стиль, линии'),
      HgItem(Icons.star, 'Избранное', 'Отметить избранным'),
      HgItem(Icons.alarm, 'Напоминание', 'Разовое или повтор'),
      HgItem(Icons.label_outline, 'Теги', 'Добавить теги'),
    ]),
    HgSection(Icons.home_outlined, _c4, false, 'Главная и навигация', [
      HgItem(Icons.search, 'Поиск', 'Поиск в заметках'),
      HgItem(Icons.tune, 'Расширенный поиск', 'Фильтр по типу/дате'),
      HgItem(Icons.calendar_month, 'Календарь', 'Заметки по дате'),
      HgItem(Icons.label, 'Категории', 'Фильтр по категории'),
    ]),
    HgSection(Icons.shield_outlined, _c6, false, 'Безопасность и синхронизация', [
      HgItem(Icons.lock, 'Заблокировать', 'Защита PIN-кодом'),
      HgItem(Icons.visibility_off, 'Режим приватности', 'Скрыть содержимое'),
      HgItem(Icons.backup_outlined, 'Резервная копия', 'Сохранить и восстановить'),
      HgItem(Icons.cloud, 'Google Drive / WebDAV', 'Шифрованная синхронизация'),
    ]),
    HgSection(Icons.handyman_outlined, _c8, false, 'Ещё', [
      HgItem(Icons.format_textdirection_r_to_l, 'Направление по строке', 'Арабский справа, английский слева'),
      HgItem(Icons.archive_outlined, 'Архив и корзина', 'Восстановить заметки'),
      HgItem(Icons.settings_outlined, 'Настройки', 'Страница и язык по умолчанию'),
    ]),
  ],
};

const Map<String, HgChrome> _hgChrome = {
  'en': HgChrome('Every tool — its shape and function', 'items', 'Updated: 2026-06-13'),
  'ar': HgChrome('كل أداة وشكلها ووظيفتها', 'عنصر', 'آخر تحديث: 2026-06-13'),
  'es': HgChrome('Cada herramienta: su forma y función', 'elementos', 'Actualizado: 2026-06-13'),
  'de': HgChrome('Jedes Werkzeug – Form und Funktion', 'Einträge', 'Aktualisiert: 2026-06-13'),
  'fil': HgChrome('Bawat tool — hugis at gamit', 'item', 'Na-update: 2026-06-13'),
  'fr': HgChrome('Chaque outil — sa forme et sa fonction', 'éléments', 'Mis à jour : 2026-06-13'),
  'id': HgChrome('Setiap alat — bentuk dan fungsinya', 'item', 'Diperbarui: 2026-06-13'),
  'it': HgChrome('Ogni strumento — forma e funzione', 'elementi', 'Aggiornato: 2026-06-13'),
  'ms': HgChrome('Setiap alat — bentuk dan fungsi', 'item', 'Dikemas kini: 2026-06-13'),
  'hi': HgChrome('हर टूल — उसका आकार और काम', 'आइटम', 'अपडेट: 2026-06-13'),
  'bn': HgChrome('প্রতিটি টুল — আকৃতি ও কাজ', 'আইটেম', 'আপডেট: 2026-06-13'),
  'fa': HgChrome('هر ابزار — شکل و کارکرد آن', 'مورد', 'به‌روزرسانی: 2026-06-13'),
  'ru': HgChrome('Каждый инструмент — форма и функция', 'элементов', 'Обновлено: 2026-06-13'),
};

List<HgSection> helpSections(String lang) => _hg[lang] ?? _hg['en']!;
HgChrome helpChrome(String lang) => _hgChrome[lang] ?? _hgChrome['en']!;
