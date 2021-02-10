require 'pp'
require 'yaml'
require 'date'
require 'optparse'
require 'fileutils'
require 'spreadsheet'

TemplatesVz                = __dir__                        # Pfad zu den Templates
AusgabeVzPrefix            = "Ausgabe"                      # Wird im gleichen Pfad erzeugt, in dem auch das Verzeichnis mit den Eingabedaten liegt
Verwendungsmatrix          = "Verwendungsmatrix.ods"        # Dateiname für die Verwendungsmatrix im Ausgabe-Verzeichnis
TemplateExam               = "TemplateExam.tex"             # Dateiname des Klausurtemplates englisch
TemplateExamSolution       = "TemplateExamSolution.tex"     # Dateiname des Klausur-Lösungs-Templates englisch
TemplateKlausur            = "TemplateKlausur.tex"          # Dateiname des Klausurtemplates deutsch
TemplateKlausurLoesung     = "TemplateKlausurLoesung.tex"   # Dateiname des Klausur-Lösungs-Templates deutsch
TemplateSerie              = "TemplateSerie.tex"            # Dateiname des Übungsaufgaben-Template deutsch
TemplateSerieLoesung       = "TemplateSerieLoesung.tex"     # Dateiname des Übungsaufgaben-Lösungs-Template deutsch
Auswahl                    = "Auswahl.tex"                  # Dateiname für beliebige Aufgabenauswahlen

# Liefert das Kürzel für das zu date gehörige Semester
# z.B. semester(Date.parse("4.5.2019")) -> "SS19" oder semester(Date.parse("7.2.2017") -> WS1718
def semester(date)
    ws = date.strftime('%y').to_i
    month = date.month
    if 4 <= month and month < 10
	"SS#{date.strftime('%y')}"
    elsif 10 <= month and month <= 12
	"WS#{ws}#{ws+1}"
    else 1 <= month and month < 4
	"WS#{ws-1}#{ws}"
    end
end

# OptionParser
ARGV << '-h' if ARGV.empty?
# Defaults
$OPTS = {
    :semester => semester(Date.today),
    :output => "output",
    :type => [],
    :name => []
}
OptionParser.new do |opts|

    opts.banner = "Aufruf: test.rb [optionen]"

    opts.on("-m", "--modify", "Yaml-Dateien werden aufdatiert") do |m|
	$OPTS[:modify] = m
    end

    opts.on("-i", "--info", "Gibt Liste der vorhandenen Aufgaben je Typ zurück.") do |i|
	$OPTS[:info] = i
    end

    opts.on("-d", "--de", "Sprache deutsch") do |d|
	$OPTS[:deutsch] = d
    end

    opts.on("-l", "--slot", "Nächste freie Aufgabennummer für einen Typ ermitteln") do |l|
	$OPTS[:slot] = l
    end

    opts.on("-p", "--path STRING", String, "Pfad zum Eingabedateienverzeichnis (Bsp.: -p input)") do |p|
	$OPTS[:path] = File.expand_path(p)
    end

    opts.on("-o", "--output STRING", String, "Name des erzeugten Latex-Files (Bsp.: -o SchwereKlausur)") do |o|
	$OPTS[:output] = o
    end

    opts.on("-s", "--semester STRING", String, "Semester (Bsp.: 'WS1819')") do |s|
	$OPTS[:semester] = s
    end

    opts.on("-t", "--type STRING", String, "Regulärer Ausdruck, um Aufgaben eines oder mehrerer Typen auszuwählen (Bsp.: -t \"Ma\")") do |t|
	$OPTS[:type] = Regexp.new(t)
    end

    opts.on("-n", "--name STRING", String, "Aufgabenauswahl durch Angabe einer Liste regulärerer Ausdrücke von NamensENDUNGEN (Bsp.: -n \"Ma1, GF1, GF2, 44\") ") do |n|
	$OPTS[:name] = n.split(/[ ,;]+/).map{ |x| Regexp.new(x + "$") }
    end

    opts.on("-r", "--exercises STRING", String, "4 Übungsaufgaben erstellen (Bsp.: \"8, 29.7.2077, 25\" entspricht 8. Serie, Abgabe am 29.7.2077, Skript bis Seite 25 erforderlich)") do |r|
	$OPTS[:exercises] = r.split(/[ ,;]+/)
    end

    opts.on("-e", "--exam", "Klausur mit 5 Aufgaben erstellen") do |e|
	$OPTS[:exam] = e
    end

    opts.on("-x", "--solution", "Lösungen erstellen") do |l|
	$OPTS[:solution] = l
    end

    opts.on("-c", "--choice", "Alle Aufgaben der Auswahl erstellen") do |c|
	$OPTS[:choice] = c
    end

    opts.on_tail("-h", "--help", "Diese Hilfe anzeigen") do
	puts opts
	puts "\nBeispiele:"
	puts "ruby x.rb -p Aufgaben/".ljust(75, " ") + "Erzeugt Verwendungsmatrix aller Aufgaben im Verzeichnis Aufgaben."
	puts " ".ljust(75, " ") + "(Die Verwendungsmatrix wird bei jedem erfolgreichen Aufruf erstellt.)"
	puts "ruby x.rb -p Aufgaben/ -i".ljust(75, " ") + "Erzeugt eine Liste der Typen und Aufgaben."
	puts "ruby x.rb -p Aufgaben/ -n \".\" -c -x".ljust(75, " ") + "Erzeugt <output>/<Auswahl>.pdf mit allen Aufgaben und Lösungen."
	puts "ruby x.rb -p Aufgaben/ -n \"tching[0-9]*\" -c".ljust(75, " ") + "Erzeugt <output>/<Auswahl>.pdf mit allen Aufgaben,"
	puts " ".ljust(75, " ") + "deren Name auf /thing[0-9]*$/ matcht."
	puts "ruby x.rb -p Aufgaben/ -l -t \"Mat\"".ljust(75, " ") + "Liefert die nächste freie Lücke für Aufgaben des Typs /Mat/."
	puts "ruby x.rb -p Aufgaben/ -e -n \"tri.*\"".ljust(75, " ") + "Erzeugt eine Klausur mit den Aufgaben, die auf /tri.*$/ matchen."
	puts " ".ljust(75, " ") + "(Vorausgesetzt, das sind genau 5 Stück.)"
	puts "ruby x.rb -r \"99, 1.1.1900; 101\" -n \"MaxFlow.*\" -p Aufgaben/".ljust(75, " ") + "Erzeugt einen Übungszettel mit den Aufgaben, die auf /MaxFlow.*$/ matchen."
	puts " ".ljust(75, " ") + "(Vorausgesetzt, das sind genau 4 Stück.)"
	puts " ".ljust(75, " ") + "99. Serie, Abgabe bis 1.1.1900, Skript wird bis Seite 101 benötigt."
	exit
    end

end.parse!
puts "\nDas sind die verwendeten Optionen:\n#$OPTS\n\n"
#

## ermittelt Multiline-Werte, die (leider) durch Aufruf von .to_yaml entstehen
#def find_multiline(yml_string)
#    #yml = File.read(yml_file)
#    [yml_string, yml_string.scan(/(?<!\\)(".*?)(?=^[\w]+:)/m).flatten]
#end
#
## formatiert die Multiline-Werte wieder zurück in "the literal style"
#def format_multiline(yml_string)
#    ym_stringl, matches = find_multiline(yml_string)
#    #pp matches[0]
#    #puts "----------------------"
#    #pp eval(matches[0].split("\n").join).sub(/^/,"|\n").split(/^/).map{|x| "        " + x}.join
#    matches.each{ |m|
#	new_key = eval(m.split("\n").join).sub(/^/,"|\n").split(/^/).map{|x| "        " + x}.join
#        yml_string.gsub!(m, new_key)
#    }
#    yml_string
#end

# lädt alle Aufgaben im angegebenen Pfadmuster in ein Array
def lade_aufgaben(path_pattern)
    Dir[path_pattern].map{ |p| YAML.load_file(p) }
end

# gibt die Aufgaben, die alle erforderlichen Informationen haben zurück. Nur auf diesen wird gearbeitet.
def check_aufgaben(aufgaben, mandatory_keys, optional_keys)
    delete_me  = []
    aufgaben.each{ |a|
	missing = mandatory_keys.sort - ( a.keys.sort - optional_keys )
	if !( missing.empty? )
	    puts "\nWarnung, fehlende Schlüssel:"
	    puts "#{a["filename"]}" + ": " + "#{missing}"
	    delete_me << a
	end
	tmp = a.clone.delete_if{ |k| optional_keys.include?(k) }
	if tmp.to_a.flatten.include?(nil)
	    puts "\nWarnung, #{a["filename"]}: verpflichtende Schlüssel #{mandatory_keys} mit leeren Werten oder Komponenten."
	    pp tmp
	    delete_me << a
	end
    }
    puts "\n #{delete_me.length} Aufgaben von #{aufgaben.length} werden verworfen.\n\n"
    aufgaben - delete_me
end

# Liefert eine Zuordnung der Einträge unter dem Schlüssel "benutzt" zu Spalten in der Verwendungsmatrix
# Wir bei der Erstellung der Verwendungstabelle benötigt
def spalten(aufgaben)
    spalten = {}
    (get_benutzt_rest(aufgaben) + get_benutzt_semester(aufgaben)).each_with_index{ |x, i| spalten[x] = i }
    spalten
end

# gibt die Aufgaben bestimmter Typen als Array zurück
# Zur Auswahl kann ein regulärer Ausdruck angegeben werden
def select_by_type(aufgaben, type)
    aufgaben.select{ |x| x["typ"] =~ type }.sort_by{ |f| f["filename"] }
end

# gibt die Aufgaben mit bestimmten Namen zurück
# Zur Auswahl kann ein regulärer Ausdruck angegeben werden
def select_by_name(aufgaben, auswahl)
    auswahl.map{ |w| aufgaben.select{ |a| a["name"] =~ w } }.flatten(1).sort_by{ |f| f["filename"] }
end

# Datiert die Schlüssel "filename" mit den aktuellen Dateinamen auf
def update_filenames(path_pattern)
    Dir[path_pattern].each{ |p|
	content = File.read(p)
	if content.match(/^filename:/)
	    File.write(p, content.sub(/^filename:.*$/, "filename: " + File.basename(p))) 
	else
	    File.write(p, content + "\nfilename: " + File.basename(p))
	end
    }
end

# Fügt das aktuelle Datum beim Schlüssel "zuletzt_benutzt" an
# Fügt das aktuelle Semester oder den per --semester angegebene String beim Schlüssel "benutzt" an
def update_aufgabe(aufgabe, semester, path)
    
    puts "------------"
    pp aufgabe["zuletzt_benutzt"].inspect

    content = File.read(path)
    if aufgabe["zuletzt_benutzt"].nil?
	aufgabe["zuletzt_benutzt"] = [Date.today.strftime("%d.%m.%Y")]
    else
	aufgabe["zuletzt_benutzt"] << Date.today.strftime("%d.%m.%Y")
    end

    if aufgabe["benutzt"].nil?
	aufgabe["benutzt"] = semester
    else
	aufgabe["benutzt"] << semester
    end

    pp content.match(/(^zuletzt_benutzt:)(.*?)(?=\w+:)/m)
    pp aufgabe["zuletzt_benutzt"].inspect

    content.sub!(/(^zuletzt_benutzt:)(.*?)(?=\w+:)/m, '\1 ' + aufgabe["zuletzt_benutzt"].inspect + "\n")
    content.sub!(/(^benutzt:)(.*?)(?=\w+:)/m, '\1 ' + (get_benutzt_rest([aufgabe]) + get_benutzt_semester([aufgabe])).inspect + "\n")
    File.write(path, content)
end

# Bildet ein Array mit Strings auf ein Array mit den in den Strings enthaltenen Zahlen ab
# Bsp.: ["uwe1977","cl1a9u82di","12.34"] -> [1977,1982,1234]
# Wird benötigt, um Slots für neue Aufgaben zu finden
def zahl_aus_name(names)
    names.map{ |f| f.gsub(/[^\d]*/,"").to_i }.sort
end

# Liste aller Namen
def alle_namen(aufgaben)
    aufgaben.map{ |a| a["name"] }.uniq.sort
end

# Liste aller Typen
def alle_typen(aufgaben)
    aufgaben.map{ |a| a["typ"] }.uniq.sort
end

# Findet den nächsten freien Slot in einem Array mit Zahlen
# Bsp.: [1,2,3,500] -> 4
def finde_luecke(ary)
    ary.select{ |x| x == ary.index(x) + 1 }.length + 1
end

# Findet den nächsten freien Slot für einen bestimmten Aufgabentyp
def finde_aufgabenluecke(aufgaben, type)
    aufgaben_namen = select_by_type(aufgaben, type).map{ |x| x["name"] }
    finde_luecke(zahl_aus_name(aufgaben_namen))
end

# schreibt die aufgaben einer serie in ein tex-file im Ausgabeverzeichnis
def schreibe_uebungsaufgaben(auswahl, nummer, abgabe, skriptseite, template, ausgabe_path)
    if auswahl.nil? or auswahl.length != 4
	puts "\nFEHLER: Es wurden nicht genau 4 Aufgaben ausgewählt: #{auswahl.map{ |a| a['name'] }}"
	exit
    else
	text = File.read(template)
	text.sub!("ReplaceAbgabedatum", abgabe)
	text.sub!("ReplaceSkript", skriptseite)
	text.sub!("ReplaceNummer", nummer)
	fname ||= "Serie_#{nummer.rjust(2, '0')}.tex"
	auswahl.each_with_index{ |a, i| 
	    text.sub!("ReplacePunkte#{i+1}", a["punkte"])
	    text.sub!("ReplaceAufgabe#{i+1}", a["latex_aufgabe"])
	}
	full_path = File.join(ausgabe_path, fname)
	pp full_path
	File.write(full_path, text)
	full_path
    end
end

def schreibe_uebungsaufgaben_loesungen(auswahl, nummer, template, ausgabe_path)
    if auswahl.nil? or auswahl.length != 4
	puts "\nFEHLER: Es wurden nicht genau 4 Aufgaben ausgewählt: #{auswahl.map{ |a| a['name'] }}"
	exit
    else
	text = File.read(template)
	text.sub!("ReplaceNummer", nummer)
	fname ||= "Serie_#{nummer.rjust(2, '0')}_Loesung.tex"
	auswahl.each_with_index{ |a, i| 
	    text.sub!("ReplacePunkte#{i+1}", a["punkte"])
	    if a["latex_loesung"].nil?
		puts "Fehler: Für Aufgabe #{a["name"]} gibt es noch keine Lösung!"
	    else
		text.sub!("ReplaceAufgabe#{i+1}", a["latex_loesung"])
	    end
	}
	full_path = File.join(ausgabe_path, fname)
	pp full_path
	File.write(full_path, text)
	full_path
    end
end

# schreibt die Klausuraufgaben ein tex-file
def schreibe_klausuraufgaben(auswahl, semester, template, ausgabe_path, deutsch)
    if auswahl.nil? or auswahl.length != 5
	puts "\nFEHLER: Es wurden nicht genau 5 Aufgaben ausgewählt: #{auswahl.map{ |a| a['name'] }}"
	exit
    else
	text = File.read(template)
	text.sub!("ReplaceSemester", semester.sub(/WS(\d{2})/,'WS\\,\1/').sub(/SS/,'SS\\,'))
	if deutsch
	    fname ||= "Klausur_#{semester}.tex"
	else
	    fname ||= "Exam_#{semester}.tex"
	end
	auswahl.each_with_index{ |a, i| 
	    text.sub!("ReplaceProblem#{i+1}", a["latex_aufgabe"])
	}
	full_path = File.join(ausgabe_path, fname)
	pp full_path
	File.write(full_path, text)
	full_path
    end
end

# schreibt die Klausuraufgaben ein tex-file
def schreibe_klausuraufgaben_loesungen(auswahl, semester, template, ausgabe_path, deutsch)
    if auswahl.nil? or auswahl.length != 5
	puts "\nFEHLER: Es wurden nicht genau 5 Aufgaben ausgewählt: #{auswahl.map{ |a| a['name'] }}"
	exit
    else
	text = File.read(template)
	text.sub!("ReplaceSemester", semester.sub(/WS(\d{2})/,'WS\\,\1/').sub(/SS/,'SS\\,'))
	if deutsch
	    fname ||= "Klausur_#{semester}_Loesung.tex"
	else
	    fname ||= "Exam_#{semester}_Solution.tex"
	end
	auswahl.each_with_index{ |a, i| 
	    if a["latex_loesung"].nil?
		puts "Fehler: Für Aufgabe #{a["name"]} gibt es noch keine Lösung!"
	    else
		text.sub!("ReplaceProblem#{i+1}", a["latex_loesung"])
	    end
	}
	full_path = File.join(ausgabe_path, fname)
	pp full_path
	File.write(full_path, text)
	full_path
    end
end

# schreibt beliebige aufgaben (ggf. mit Lösung) in ein tex-file
def schreibe_aufgaben(auswahl, new_tex_file, mit_loesung)
    if auswahl.nil?
	puts "\nFEHLER: Es wurden keine Aufgaben ausgewählt."
	exit
    else
	file = File.open(new_tex_file, 'w')
	file.puts("\\documentclass{article}\n\\usepackage[colorlinks=true,linkcolor=black]{hyperref}\n\\usepackage{tocloft}\n\\renewcommand{\\cftsecleader}{\\cftdotfill{\\cftdotsep}}\\begin{document}\n\\tableofcontents\n\n")
	auswahl.group_by{ |w| w["typ"] }.each{ |k,v|
	    file.puts("\\section{#{k}}\n")
	    if mit_loesung
		v.each{ |a| file.puts("\\subsection{#{a["name"]}}\n#{a["latex_aufgabe"]}\\\\[2ex]\nSolution:\\\\[1ex]\n#{a["latex_loesung"]}") }
	    else
		v.each{ |a| file.puts("\\subsection{#{a["name"]}}\n#{a["latex_aufgabe"]}") }
	    end
	}
	file.puts("\n\\end{document}")
	file.close
    end
    2.times{ system("pdflatex -output-directory #{AusgabeVz} #{new_tex_file}") }
end

# "WS1718" -> 17.18
def semester_to_f(nutzungssemester)
    nutzungssemester.gsub(/[^\d]*/,"").sub(/(\d{2})(\d{2})/,'\1.\2').to_f
end

# Spaltenbreite in Tabelle anpassen
def width(int, workbook)
    workbook.worksheets.each{ |s| s.column(0).width = 1.66 * int }
    workbook.worksheets.each{ |s| (1..s.column_count).each{ |idx| s.column(idx).width = int } }
end

# Zeilenhöhe in Tabelle anpassen
def height(int, workbook)
    workbook.worksheets.each{ |s|
	s.rows.each{ |r| r.height = int }
    }
end

# Liefert alle Semester, in denen mal irgendeine Aufgabe genutzt wurde
# Sortierung erfolgt zeitlich
# Erkennungsmuster ist SS17, WS1718 etc.
# Wir bei der Erstellung der Verwendungstabelle benötigt
def get_benutzt_semester(aufgaben)
    aufgaben.map{ |z| z["benutzt"] }.flatten.uniq.select{ |s| s =~ /[SW]S\d{2}{0,2}/ }.sort{ |x, y| semester_to_f(x) <=> semester_to_f(y) }
end

# Liefert die Einträge beim Schlüssel "benutzt", die nicht als Semester erkannt werden, z.B. XYZ123
# Sortierung erfolgt alphabetisch
# Wir bei der Erstellung der Verwendungstabelle benötigt
def get_benutzt_rest(aufgaben)
    aufgaben.map{ |z| z["benutzt"] }.flatten.uniq.select{ |s| s !~ /[SW]S\d{2}{0,2}/ }.sort
end

# Erzeugt die Excel-Tabelle mit den Informationen über die Verwendung
# der Aufgabentypen
def tabelle(aufgaben, spalten, ods_file)
    ty = alle_typen(aufgaben) # alle typen, die es gibt. Das werden die Tabellenblätter
    Spreadsheet.client_encoding = 'UTF-8'
    book = Spreadsheet::Workbook.new # neue Tabelle anlegen
    format_data = Spreadsheet::Format.new :weight => :bold, :color => :blue, :size => 14, :horizontal_align => :centre #, :pattern_fg_color => :green, :pattern => 1 # Format für die Daten
    format_row_header = Spreadsheet::Format.new :weight => :bold, :size => 14, :right => :thin # Format für die Zeilenüberschriften
    format_col_header = Spreadsheet::Format.new :weight => :bold, :size => 14, :horizontal_align => :centre, :bottom => :thin # Format für die Spaltenüberschriften
    format_row_col_header = Spreadsheet::Format.new :size => 14, :horizontal_align => :centre, :bottom => :thin, :right => :thin # Format für die Zelle (0,0)
    ty.each{ |t| 
	sheet = book.create_worksheet(:name => t) # neues Blatt zum Typ
	a = select_by_type(aufgaben, /#{t}/) # Aufgaben des Typs wählen
	sheet.row(0).push "name/semester", *(spalten.keys) # Überschriftenzeile einfügen
	sheet.row(0).default_format = format_col_header # Überschriftenzeile formatieren
	sheet.row(0).set_format(0, format_row_col_header) # Legende formatieren
	a.each_with_index{ |x, i|
	    sheet.row(i+1)[0] = x["name"] # der Aufgabenname, als Zeilenüberschrift
	    sheet.row(i+1).set_format(0, format_row_header) # Zeilenüberschrift formatieren
	    x["benutzt"].each{ |b|
	        sheet.row(i+1)[spalten[b]+1] = "X" # das Kreuz machen
		sheet.row(i+1).set_format(spalten[b]+1, format_data) # das Kreuz formatieren
	    }
	}
    }
    width(13, book) # Zellenbreite setzen
    height(18, book) # Zellenhöhe setzen
    book.write(ods_file) # Datei schreiben
end

###################
## Hauptprogramm ## 
###################

# Eingabedaten
Eingabedaten = $OPTS[:path] + "\/*.yml"

# Ausgabeverzeichnis (Update der yml erfolgt aber im Eingabedatenverzeichnis)
AusgabeVz = File.join(File.expand_path("..", $OPTS[:path]), AusgabeVzPrefix + "_" + File.basename($OPTS[:path]))
Dir.mkdir(AusgabeVz) unless File.exists?(AusgabeVz)

# Schlüssel "filename" wird auch ohne $OPTS[:modify] aufdateirt, da unkritisch und hilfreich.
update_filenames(Eingabedaten)

# Alle Aufgaben laden
aa = lade_aufgaben(Eingabedaten)

# Unvollständige Aufgaben aussortieren
if $OPTS[:solution]
    aabereinigt = check_aufgaben(aa, ["name", "typ", "benutzt", "latex_aufgabe", "latex_loesung", "filename", "punkte"], ["kommentar", "zuletzt_benutzt"] )
else
    aabereinigt = check_aufgaben(aa, ["name", "typ", "benutzt", "latex_aufgabe", "filename", "punkte"], ["latex_loesung", "kommentar", "zuletzt_benutzt"] )
end

# Spaltenüberschriften für die Nutzungstabelle ermitteln
spalten = spalten(aabereinigt)

# Nutzungstabelle erstellen
tabelle(aabereinigt, spalten, File.join(AusgabeVz, Verwendungsmatrix)) 

# Informationsausgabe
if $OPTS[:info]
    puts "Aufgaben im Pool:"
    groups = aabereinigt.group_by{ |a| a["typ"] }
    groups.each{ |k,v| puts "#{k}:"; puts v.map{ |x| "     " + x["name"] }.sort }
    exit
end

# Namensauswahl
if $OPTS[:name]
    auswahl_name = select_by_name(aabereinigt, $OPTS[:name])
    puts "\nAlle ausgewählten Namen:\n#{auswahl_name.map{ |a| a["name"] }}\n\n"
    auswahl_name
end

# Typauswahl
if $OPTS[:type]
    auswahl_typ = select_by_type(aabereinigt, $OPTS[:type])
    puts "\nAlle ausgewählten Typen:\n#{auswahl_typ.map{ |a| a["name"] }}"
    auswahl_typ
end

# Übungsaufgaben schreiben
if !($OPTS[:exercises].nil? or $OPTS[:exercises].empty?)
    if $OPTS[:exercises].length != 3
	puts "Bei der Option -r / --exercises werden genau 3 Komma, Leerzeichen, oder Semikolon getrennte Argumente erwartet. Übergeben wurde #{$OPTS[:exercises]}."
	exit
    else
	if $OPTS[:solution]
	    fname = schreibe_uebungsaufgaben_loesungen(auswahl_name, $OPTS[:exercises][0], File.join(TemplatesVz, TemplateSerieLoesung), AusgabeVz)
	else
	    fname = schreibe_uebungsaufgaben(auswahl_name, *$OPTS[:exercises], File.join(TemplatesVz, TemplateSerie), AusgabeVz)
	end
	system("pdflatex -output-directory=#{AusgabeVz} #{fname}")
    end
end

# Klausursaufgaben schreiben
if $OPTS[:exam]
    if $OPTS[:deutsch]
	if $OPTS[:solution]
	    fname = schreibe_klausuraufgaben_loesungen(auswahl_name, $OPTS[:semester], File.join(TemplatesVz, TemplateKlausurLoesung), AusgabeVz, $OPTS[:deutsch])
	else
	    fname = schreibe_klausuraufgaben(auswahl_name, $OPTS[:semester], File.join(TemplatesVz, TemplateKlausur), AusgabeVz, $OPTS[:deutsch])
	end
    else
	if $OPTS[:solution]
	    fname = schreibe_klausuraufgaben_loesungen(auswahl_name, $OPTS[:semester], File.join(TemplatesVz, TemplateExamSolution), AusgabeVz, $OPTS[:deutsch])
	else
	    fname = schreibe_klausuraufgaben(auswahl_name, $OPTS[:semester], File.join(TemplatesVz, TemplateExam), AusgabeVz, $OPTS[:deutsch])
	end
    end
    system("pdflatex -output-directory=#{AusgabeVz} #{fname}")
end

# Beliebige Auswahlen schreiben
if $OPTS[:choice]
    auswahl = select_by_type(aabereinigt, $OPTS[:type]) + select_by_name(aabereinigt, $OPTS[:name]).sort_by{ |a| a["name"] }
    schreibe_aufgaben(auswahl, File.join(AusgabeVz, Auswahl), $OPTS[:solution])
end

if $OPTS[:modify] and ($OPTS[:exam] or $OPTS[:exercises])
    auswahl_name.each{ |a| puts "update #{a['name']}"; update_aufgabe(a, $OPTS[:semester], File.join($OPTS[:path], a["filename"])) }
end

if $OPTS[:slot]
    puts "\nLücke für #{$OPTS[:type].inspect} ist #{finde_aufgabenluecke(aabereinigt, $OPTS[:type])}\n\n"
end
